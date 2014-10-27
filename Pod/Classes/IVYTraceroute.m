//
//  IVYTraceroute.m
//  Pods
//
//  Created by ivoryxiong on 14/10/27.
//
//

#import "IVYTraceroute.h"
#import "IVYHop.h"

#include <netdb.h>
#include <arpa/inet.h>
#include <sys/time.h>

@interface IVYTraceroute ()
@property (nonatomic, assign) int udpPort;
@property (nonatomic, assign) int maxTTL;
@property (nonatomic, assign) NSTimeInterval readTimeout;
@property (nonatomic, assign) int maxAttempts;
@property (nonatomic, assign, getter = isRunning) BOOL running;

@property (nonatomic, copy) NSString *runningSyn;
@property (nonatomic, strong) NSMutableArray *hops;

@property (nonatomic, copy) IVYTracerouteHandler handler;
@property (nonatomic, copy) IVYTracerouteProcessHandler processHandler;
@end

static IVYTraceroute *_shareInstance = nil;

@implementation IVYTraceroute
+ (instancetype)sharedTraceroute {
    if (!_shareInstance) {
        dispatch_once_t token;
        dispatch_once(&token, ^{
            _shareInstance = [[IVYTraceroute alloc] init];
        });
    }

    return _shareInstance;
}

+ (instancetype)sharedTracerouteWithMaxTTL:(int)ttl timeout:(NSTimeInterval)timeout maxAttempts:(int)attempts port:(int)port {
    if (!_shareInstance) {
        dispatch_once_t token;
        dispatch_once(&token, ^{
            _shareInstance = [[IVYTraceroute alloc] initWithMaxTTL:ttl timeout:timeout maxAttempts:attempts port:port];
        });
    }

    return _shareInstance;
}

- (instancetype)init {
    return [self initWithMaxTTL:IVY_TRACEROUTE_MAX_TTL timeout:IVY_TRACEROUTE_TIMEOUT maxAttempts:IVY_TRACEROUTE_ATTEMPTS port:IVY_TRACEROUTE_PORT];
}

- (instancetype)initWithMaxTTL:(int)ttl timeout:(int)timeout maxAttempts:(int)attempts port:(int)port {
    self = [super init];

    if (self) {
        self.maxTTL = ttl;
        self.udpPort = port;
        self.readTimeout = timeout;
        self.maxAttempts = attempts;
    }

    return self;
}

- (void)tracerouteToHost:(NSString *)host process:(IVYTracerouteProcessHandler)processHandler handler:(IVYTracerouteHandler)handler {
    self.handler = handler;
    self.processHandler = processHandler;

    [self doTraceRoute:host];
}

- (void)doTraceRoute:(NSString *)host {
    struct hostent *host_entry = gethostbyname(host.UTF8String);
    char *ip_addr;

    ip_addr = inet_ntoa(*((struct in_addr *)host_entry->h_addr_list[0]));
    int recv_sock;
    int send_sock;

    self.running = true;
    self.hops = [NSMutableArray array];

    if ((recv_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)) < 0) {
        self.handler(false, nil);
        return;
    }

    if ((send_sock = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
        self.handler(false, nil);
        return;
    }

    struct sockaddr_in destination, fromAddr;
    memset(&destination, 0, sizeof(destination));
    destination.sin_family = AF_INET;
    destination.sin_addr.s_addr = inet_addr(ip_addr);
    destination.sin_port = htons(self.udpPort);
    struct timeval tv;
    tv.tv_sec = self.readTimeout;
    tv.tv_usec = 0;
    setsockopt(recv_sock, SOL_SOCKET, SO_RCVTIMEO, (char *)&tv, sizeof(struct timeval));
    char *cmsg = "GET / HTTP/1.1\r\n\r\n";
    socklen_t n = sizeof(fromAddr);
    char buf[100];

    int ttl = 1;

    while (ttl <= self.maxTTL) {
        bool icmp = false;
        IVYHop *routeHop = nil;
        memset(&fromAddr, 0, sizeof(fromAddr));

        if (setsockopt(send_sock, IPPROTO_IP, IP_TTL, &ttl, sizeof(ttl)) < 0) {
            self.handler(false, [self.hops copy]);
        }

        for (int try = 0; try < self.maxAttempts; try++) {
            NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];

            if (sendto(send_sock, cmsg, sizeof(cmsg), 0, (struct sockaddr *)&destination, sizeof(destination)) != sizeof(cmsg) ) {
                NSLog(@"WARN in send to...\n@");
            }

            long res = 0;

            if ( (res = recvfrom(recv_sock, buf, 100, 0, (struct sockaddr *)&fromAddr, &n)) < 0l) {
                NSLog(@"WARN [%d/%d] %s; recvfrom returned %ld\n", try, self.maxAttempts, strerror(errno), res);
            } else {
                NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSince1970] - startTime;
                char display[16] = {0};
                icmp = true;

                inet_ntop(AF_INET, &fromAddr.sin_addr.s_addr, display, sizeof(display));
                NSString *hostAddress = [NSString stringWithFormat:@"%s", display];
                NSString *hostName = [self hostnameForAddress:hostAddress];

                routeHop = [[IVYHop alloc] initWithHostName:hostName hostAddress:hostAddress ttl:ttl elapsedTime:elapsedTime];
                break;
            }

            @synchronized(_runningSyn) {
                if (![self isRunning]) {
                    ttl = self.maxTTL;
                    icmp = true;
                    break;
                }
            }
        }

        if (!icmp) {
            routeHop = [[IVYHop alloc] initWithHostName:@"*" hostAddress:@"*" ttl:ttl elapsedTime:0];
        }

        if (routeHop) {
            [self.hops addObject:routeHop];
            self.processHandler(routeHop, [self.hops copy]);
        }

        ttl++;
    }

    self.running = false;

    self.handler(YES, [self.hops copy]);
}

- (void)stopTrace {
    @synchronized(_runningSyn) {
        self.running = false;
    }
}

#pragma marks - network utils
- (NSString *)hostnameForAddress:(NSString *)address {
    NSArray *hostnames = [self hostnamesForAddress:address];
    if ([hostnames count] > 0)
        return [hostnames objectAtIndex:0];
    else
        return nil;
}

- (NSArray *)hostnamesForAddress:(NSString *)address {
    // Get the host reference for the given address.
    struct addrinfo      hints;
    struct addrinfo      *result = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_flags    = AI_NUMERICHOST;
    hints.ai_family   = PF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = 0;
    int errorStatus = getaddrinfo([address cStringUsingEncoding:NSASCIIStringEncoding], NULL, &hints, &result);
    if (errorStatus != 0) return nil;
    CFDataRef addressRef = CFDataCreate(NULL, (UInt8 *)result->ai_addr, result->ai_addrlen);
    if (addressRef == nil) return nil;
    freeaddrinfo(result);
    CFHostRef hostRef = CFHostCreateWithAddress(kCFAllocatorDefault, addressRef);
    if (hostRef == nil) return nil;
    CFRelease(addressRef);
    BOOL isSuccess = CFHostStartInfoResolution(hostRef, kCFHostNames, NULL);
    if (!isSuccess) return nil;
    
    // Get the hostnames for the host reference.
    CFArrayRef hostnamesRef = CFHostGetNames(hostRef, NULL);
    NSMutableArray *hostnames = [NSMutableArray array];
    for (int currentIndex = 0; currentIndex < [(__bridge NSArray *)hostnamesRef count]; currentIndex++) {
        [hostnames addObject:[(__bridge NSArray *)hostnamesRef objectAtIndex:currentIndex]];
    }
    
    return hostnames;
}

@end