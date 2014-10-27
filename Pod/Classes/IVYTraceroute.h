//
//  IVYTraceroute.h
//  Pods
//
//  Created by ivoryxiong on 14/10/27.
//
//

#import <Foundation/Foundation.h>

#import "IVYHop.h"

static const int IVY_TRACEROUTE_PORT     = 80;
static const int IVY_TRACEROUTE_MAX_TTL  = 32;
static const int IVY_TRACEROUTE_ATTEMPTS = 2;
static const int IVY_TRACEROUTE_TIMEOUT  = 5;

typedef void(^IVYTracerouteHandler)(BOOL success, NSArray *hops);
typedef void(^IVYTracerouteProcessHandler)(IVYHop *routeHop, NSArray *hops);

@interface IVYTraceroute : NSObject
+ (instancetype)sharedTraceroute;
+ (instancetype)sharedTracerouteWithMaxTTL:(int)ttl timeout:(NSTimeInterval)timeout maxAttempts:(int)attempts port:(int)port;

- (void)tracerouteToHost:(NSString *)host process:(IVYTracerouteProcessHandler)processHandler handler:(IVYTracerouteHandler)handler;
- (void)stopTrace;
@end
