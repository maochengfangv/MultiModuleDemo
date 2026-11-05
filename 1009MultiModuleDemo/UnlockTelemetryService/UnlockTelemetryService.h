//
//  UnlockTelemetryService.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol UnlockTelemetryService <NSObject>

- (void)trackEvent:(NSString *)event attributes:(nullable NSDictionary<NSString *, id> *)attributes;
- (void)incrementMetric:(NSString *)metricKey delta:(double)delta;
- (void)accumulateDurationMetric:(NSString *)metricKey seconds:(NSTimeInterval)seconds;
- (NSDictionary<NSString *, id> *)currentPowerMetricsSnapshot;

@end

NS_ASSUME_NONNULL_END
