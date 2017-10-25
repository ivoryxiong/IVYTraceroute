//
//  IVYTraceroute.m
//  Pods
//
//  Created by CocoaPods on 14/10/27.
//  Copyright (c) 2014 ivoryxiong. All rights reserved.
//

#import "IVYTraceroute.h"
#import "IVYHop.h"

#include <netdb.h>
#include <arpa/inet.h>
#include <sys/time.h>
#include <sys/socket.h>

#pragma mark - ICMP On-The-Wire Format
static uint16_t in_cksum(const void *buffer, size_t bufferLen) {
    // This is the standard BSD checksum code, modified to use modern types.
    size_t bytesLeft;
    int32_t sum;
    const uint16_t *cursor;

    union {
        uint16_t us;
        uint8_t uc[2];
    } last;
    uint16_t answer;

    bytesLeft = bufferLen;
    sum = 0;
    cursor = buffer;

    /*
     * Our algorithm is simple, using a 32 bit accumulator (sum), we add
     * sequential 16 bit words to it, and at the end, fold back all the
     * carry bits from the top 16 bits into the lower 16 bits.
     */
    while (bytesLeft > 1) {
        sum += *cursor;
        cursor += 1;
        bytesLeft -= 2;
    }

    /* mop up an odd byte, if necessary */
    if (bytesLeft == 1) {
        last.uc[0] = *(const uint8_t *)cursor;
        last.uc[1] = 0;
        sum += last.us;
    }

    /* add back carry outs from top 16 bits to low 16 bits */
    sum = (sum >> 16) + (sum & 0xffff);         /* add hi 16 to low 16 */
    sum += (sum >> 16);                         /* add carry */
    answer = (uint16_t) ~sum;       /* truncate to 16 bits */

    return answer;
}

@interface IVYTraceroute ()
@property (nonatomic, assign) int udpPort;
@property (nonatomic, assign) int maxTTL;
@property (nonatomic, assign) NSTimeInterval readTimeout;
@property (nonatomic, assign) int maxAttempts;
@property (nonatomic, assign, getter = isRunning) BOOL running;

@property (nonatomic, copy) NSString *runningSyn;
@property (nonatomic, strong) NSMutableArray *hops;
@property (nonatomic, assign) NSInteger identifier;
@property (nonatomic, assign) NSInteger nextSequenceNumber;

@property (nonatomic, copy) IVYTracerouteHandler handler;
@property (nonatomic, copy) IVYTracerouteProcessHandler processHandler;
@end


@implementation IVYTraceroute
+ (instancetype)sharedTraceroute {
    static IVYTraceroute *_shareInstance = nil;
    static dispatch_once_t oncePredicate;

    dispatch_once(&oncePredicate, ^{
        _shareInstance = [[IVYTraceroute alloc] init];
    });

    return _shareInstance;
}

+ (instancetype)sharedTracerouteWithMaxTTL:(int)ttl timeout:(NSTimeInterval)timeout maxAttempts:(int)attempts port:(int)port {
    static IVYTraceroute *_shareInstance = nil;
    static dispatch_once_t oncePredicate;

    dispatch_once(&oncePredicate, ^{
        _shareInstance = [[IVYTraceroute alloc] initWithMaxTTL:ttl timeout:timeout maxAttempts:attempts port:port];
    });

    return _shareInstance;
}

- (instancetype)init {
    return [self initWithMaxTTL:kIVYTraceRouteMaxTTL timeout:kIVYTraceRouteTimeout maxAttempts:kIVYTraceRouteMaxAttempts port:kIVYTraceRoutePort];
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

- (void)stopTrace {
    @synchronized(_runningSyn) {
        self.running = false;
    }
}

- (void)tracerouteToHost:(NSString *)host process:(IVYTracerouteProcessHandler)processHandler handler:(IVYTracerouteHandler)handler {
    self.handler = handler;
    self.processHandler = processHandler;

    [self doTraceRoute:host];
}

- (void)doTraceRoute:(NSString *)host {
    struct hostent *host_entry = gethostbyname(host.UTF8String);
    char *ip_addr;
	
	if (!host_entry) {
		self.handler(false, nil);
		return;
	}
	
    ip_addr = inet_ntoa(*((struct in_addr *)host_entry->h_addr_list[0]));
    int recv_sock;
    int send_sock;

    self.running = true;
    self.hops = [NSMutableArray array];

    if ((recv_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)) < 0) {
        self.handler(false, nil);
        return;
    }

    if ((send_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)) < 0) {
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
    socklen_t addrLen = sizeof(fromAddr);
    void *buffer = NULL;

    int ttl = 1;
    NSData *packet = nil;
    const struct IPHeader *ipPtr;
    const ICMPHeader *icmpPtr;
    self.identifier = 0;
    self.nextSequenceNumber = 0;

    while (ttl <= self.maxTTL) {
        bool icmp = false;
        IVYHop *routeHop = nil;
        memset(&fromAddr, 0, sizeof(fromAddr));

        if (setsockopt(send_sock, IPPROTO_IP, IP_TTL, &ttl, sizeof(ttl)) < 0) {
            self.handler(false, [self.hops copy]);
        }

        for (int try = 0; try < self.maxAttempts; try++) {
            NSTimeInterval begTime = [[NSDate date] timeIntervalSince1970];
            packet = [self packEchoPacket];

            if (sendto(send_sock, [packet bytes], [packet length], 0, (struct sockaddr *)&destination, sizeof(destination)) != [packet length]) {
                NSLog(@"WARN in send to...\n");
                continue;
            }

            enum { kBufferSize = 65535 };
            // 65535 is the maximum IP packet size, which seems like a reasonable bound
            // here (plus it's what <x-man-page://8/ping> uses).
            buffer = malloc(kBufferSize);

            ssize_t bytesRead = recvfrom(recv_sock, buffer, kBufferSize, 0, (struct sockaddr *)&fromAddr, &addrLen);

            if (bytesRead > 0) {
                NSMutableData *packet = [NSMutableData dataWithBytes:buffer length:(NSUInteger)bytesRead];

                icmpPtr = [[self class] icmpInPacket:packet];

                if (icmpPtr) {
                    NSLog(@"#%u ICMP type=%u, code=%u, identifier=%u", (unsigned int)OSSwapBigToHostInt16(icmpPtr->sequenceNumber), (unsigned int)icmpPtr->type, (unsigned int)icmpPtr->code, (unsigned int)OSSwapBigToHostInt16(icmpPtr->identifier) );

                    ipPtr = (const IPHeader *)[packet bytes];
                    NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSince1970] - begTime;
                    routeHop = [[IVYHop alloc] initWithHostAddress:[NSString stringWithFormat:@"%u.%u.%u.%u", ipPtr->sourceAddress[0], ipPtr->sourceAddress[1], ipPtr->sourceAddress[2], ipPtr->sourceAddress[3] ] ttl:ttl elapsedTime:elapsedTime];
                    if (routeHop) {
                        [self.hops addObject:routeHop];
                        self.processHandler(routeHop, [self.hops copy]);
                    }

                    icmp = true;
                    if (((unsigned int)icmpPtr->type) == kICMPTypeDestinationUnreachable
                        || ((unsigned int)icmpPtr->type) == kICMPTypeEchoReply) {
                        ttl = self.maxTTL;
                        free(buffer);
                        buffer = NULL;
                        break;
                    }
                }
            }

            if (buffer != NULL) {
                free(buffer);
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
            routeHop = [[IVYHop alloc] initWithHostAddress:@"*" ttl:ttl elapsedTime:0];
            if (routeHop) {
                [self.hops addObject:routeHop];
                self.processHandler(routeHop, [self.hops copy]);
            }
        }

        ttl++;
    }

    self.running = false;
    self.handler(YES, [self.hops copy]);
}

- (NSMutableData *)packEchoPacket {
    ICMPHeader *icmpPtr;

    NSData *payload = [[NSString stringWithFormat:@"%0.06f", [[NSDate date] timeIntervalSince1970] ] dataUsingEncoding:NSASCIIStringEncoding];
    NSMutableData *packet = [NSMutableData dataWithLength:sizeof(*icmpPtr) + [payload length]];

    icmpPtr = [packet mutableBytes];
    icmpPtr->type = kICMPTypeEchoRequest;
    icmpPtr->code = 0;
    icmpPtr->checksum = 0;
    icmpPtr->identifier     = OSSwapHostToBigInt16(self.identifier);
    icmpPtr->sequenceNumber = OSSwapHostToBigInt16(self.nextSequenceNumber);
    memcpy(&icmpPtr[1], [payload bytes], [payload length]);

    // The IP checksum returns a 16-bit number that's already in correct byte order
    // (due to wacky 1's complement maths), so we just put it into the packet as a
    // 16-bit unit.
    icmpPtr->checksum = in_cksum([packet bytes], [packet length]);

    self.nextSequenceNumber += 1;

    return packet;
}

#pragma mark - utils
+ (NSUInteger)icmpHeaderOffsetInPacket:(NSData *)packet {
    NSUInteger result;
    const struct IPHeader *ipPtr;
    size_t ipHeaderLength;

    result = NSNotFound;

    if ([packet length] >= (sizeof(IPHeader) + sizeof(ICMPHeader))) {
        ipPtr = (const IPHeader *)[packet bytes];
        assert((ipPtr->versionAndHeaderLength & 0xF0) == 0x40);     // IPv4
        assert(ipPtr->protocol == 1);                               // ICMP
        ipHeaderLength = (ipPtr->versionAndHeaderLength & 0x0F) * sizeof(uint32_t);

        if ([packet length] >= (ipHeaderLength + sizeof(ICMPHeader))) {
            result = ipHeaderLength;
        }
    }

    return result;
}

/**
 *  convert packet (NSData) to ICMP struct
 *
 *  @param packet the packet data
 *
 *  @return icmp struct
 */
+ (const struct ICMPHeader *)icmpInPacket:(NSData *)packet {
    const struct ICMPHeader *result;
    NSUInteger icmpHeaderOffset;
    
    result = nil;
    icmpHeaderOffset = [self icmpHeaderOffsetInPacket:packet];
    
    if (icmpHeaderOffset != NSNotFound) {
        result = (const struct ICMPHeader *)(((const uint8_t *)[packet bytes]) + icmpHeaderOffset);
    }
    
    return result;
}

@end
