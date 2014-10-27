//
//  IVYHop.m
//  Pods
//
//  Created by ivoryxiong on 14/10/27.
//
//

#import "IVYHop.h"

@implementation IVYHop

- (instancetype)initWithHostName:(NSString *)hostName hostAddress:(NSString *)hostAddress ttl:(int)ttl elapsedTime:(NSTimeInterval)elapsedTime {
    self = [super init];
    if (self) {
        self.hostName = hostName;
        self.hostAddress = hostAddress;
        self.ttl = ttl;
        self.elapsedTime = elapsedTime;
    }
    return self;
}

-(NSString*)description {
    NSMutableString* text = [NSMutableString stringWithFormat:@"<%@> \n", [self class]];
    [text appendFormat:@"   [hostAddress]: %@\n", _hostAddress];
    [text appendFormat:@"   [hostName]: %@\n", _hostName];
    [text appendFormat:@"   [ttl]: %d\n", _ttl];
    [text appendFormat:@"   [elapsedTime]: %0.6f\n", _elapsedTime];
    [text appendFormat:@"</%@>", [self class]];
    return text;
}

@end
