//
//  IVYHop.h
//  Pods
//
//  Created by ivoryxiong on 14/10/27.
//
//

#import <Foundation/Foundation.h>

@interface IVYHop : NSObject
@property (nonatomic, copy) NSString *hostAddress;
@property (nonatomic, copy) NSString *hostName;
@property (nonatomic, assign) int ttl;
@property (nonatomic, assign) NSTimeInterval elapsedTime;

- (instancetype)initWithHostName:(NSString *)hostName hostAddress:(NSString *)hostAddress ttl:(int)ttl elapsedTime:(NSTimeInterval)elapsedTime;
@end
