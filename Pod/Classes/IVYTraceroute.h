//
//  IVYTraceroute.h
//  Pods
//
//  inspired by Apple's implemention by DTS, @see https://developer.apple.com/library/mac/samplecode/simpleping/introduction/intro.html
//  for more detail, @see http://courses.cs.vt.edu/cs4254/fall04/slides/raw_6.pdf
//
//  Created by CocoaPods on 14/10/27.
//  Copyright (c) 2014 ivoryxiong. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AssertMacros.h>
#if TARGET_OS_EMBEDDED || TARGET_IPHONE_SIMULATOR
#import <CFNetwork/CFNetwork.h>
#else
#import <CoreServices/CoreServices.h>
#endif

#import "IVYHop.h"

static const int kIVYTraceRoutePort        = 33443;
static const int kIVYTraceRouteMaxTTL      = 32;
static const int kIVYTraceRouteMaxAttempts = 2;
static const int kIVYTraceRouteTimeout     = 20;

typedef void(^IVYTracerouteHandler)(BOOL success, NSArray *hops);
typedef void(^IVYTracerouteProcessHandler)(IVYHop *routeHop, NSArray *hops);

@interface IVYTraceroute : NSObject
+ (instancetype)sharedTraceroute;
+ (instancetype)sharedTracerouteWithMaxTTL:(int)ttl timeout:(NSTimeInterval)timeout maxAttempts:(int)attempts port:(int)port;

- (void)tracerouteToHost:(NSString *)host process:(IVYTracerouteProcessHandler)processHandler handler:(IVYTracerouteHandler)handler;
- (void)stopTrace;
@end

#pragma mark * IP and ICMP On-The-Wire Format
// The following declarations specify the structure of ping packets on the wire.

// IP header structure:
typedef struct IPHeader {
    uint8_t     versionAndHeaderLength;
    uint8_t     differentiatedServices;
    uint16_t    totalLength;
    uint16_t    identification;
    uint16_t    flagsAndFragmentOffset;
    uint8_t     timeToLive;
    uint8_t     protocol;
    uint16_t    headerChecksum;
    uint8_t     sourceAddress[4];
    uint8_t     destinationAddress[4];
} IPHeader;

check_compile_time(sizeof(IPHeader) == 20);
check_compile_time(offsetof(IPHeader, versionAndHeaderLength) == 0);
check_compile_time(offsetof(IPHeader, differentiatedServices) == 1);
check_compile_time(offsetof(IPHeader, totalLength) == 2);
check_compile_time(offsetof(IPHeader, identification) == 4);
check_compile_time(offsetof(IPHeader, flagsAndFragmentOffset) == 6);
check_compile_time(offsetof(IPHeader, timeToLive) == 8);
check_compile_time(offsetof(IPHeader, protocol) == 9);
check_compile_time(offsetof(IPHeader, headerChecksum) == 10);
check_compile_time(offsetof(IPHeader, sourceAddress) == 12);
check_compile_time(offsetof(IPHeader, destinationAddress) == 16);

// ICMP type and code combinations:
enum {
    kICMPTypeEchoReply   = 0,           // code is always 0
    kICMPTypeDestinationUnreachable = 3,
    kICMPTypeEchoRequest = 8,
    kICMPTypeTimeExceeded = 11
};

// ICMP header structure:
typedef struct ICMPHeader {
    uint8_t     type;
    uint8_t     code;
    uint16_t    checksum;
    uint16_t    identifier;
    uint16_t    sequenceNumber;
} ICMPHeader;

check_compile_time(sizeof(ICMPHeader) == 8);
check_compile_time(offsetof(ICMPHeader, type) == 0);
check_compile_time(offsetof(ICMPHeader, code) == 1);
check_compile_time(offsetof(ICMPHeader, checksum) == 2);
check_compile_time(offsetof(ICMPHeader, identifier) == 4);
check_compile_time(offsetof(ICMPHeader, sequenceNumber) == 6);