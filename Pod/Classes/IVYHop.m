//
//  IVYHop.m
//  Pods
//
//  Created by CocoaPods on 14/10/27.
//  Copyright (c) 2014 ivoryxiong. All rights reserved.
//

#import "IVYHop.h"

@implementation IVYHop

- (instancetype)initWithHostAddress:(NSString *)hostAddress ttl:(int)ttl elapsedTime:(NSTimeInterval)elapsedTime {
    self = [super init];
    if (self) {
        self.hostAddress = hostAddress;
        self.ttl = ttl;
        self.elapsedTime = elapsedTime;
    }
    return self;
}

-(NSString*)description {
    NSString *className = NSStringFromClass([self class]);
    return [NSString stringWithFormat:@"<%@>\n"
            "[ttl]:%d\n"
            "[hostAddress]:%@\n"
            "[elapsedTime]:%0.6f\n"
            "</%@>",
            className,
            self.ttl,
            self.hostAddress,
            self.elapsedTime,
            className];
}

@end
