//
//  PerformanceMetricKitSubscriber.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/11/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^PerformanceMetricKitPayloadHandler)(NSDictionary<NSString *, id> *payload);

@interface PerformanceMetricKitSubscriber : NSObject

+ (instancetype)sharedInstance;

- (void)startWithPayloadHandler:(PerformanceMetricKitPayloadHandler)handler;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
