//
//  PerformanceService.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/11/5.
//

#import <Foundation/Foundation.h>

@class PerformanceMonitorConfig;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const PerformanceDidCaptureEventNotification;
FOUNDATION_EXPORT NSString * const PerformanceEventNameKey;
FOUNDATION_EXPORT NSString * const PerformanceEventAttributesKey;

@protocol PerformanceService <NSObject>

- (void)startMonitoring;
- (void)startMonitoringWithConfig:(nullable PerformanceMonitorConfig *)config;
- (void)stopMonitoring;

- (void)beginTrace:(NSString *)traceName;
- (void)endTrace:(NSString *)traceName;
- (void)recordTrace:(NSString *)traceName duration:(NSTimeInterval)duration attributes:(nullable NSDictionary<NSString *, id> *)attributes;

- (NSDictionary<NSString *, id> *)currentSnapshot;
- (NSArray<NSDictionary<NSString *, id> *> *)recentEvents;

@end

NS_ASSUME_NONNULL_END
