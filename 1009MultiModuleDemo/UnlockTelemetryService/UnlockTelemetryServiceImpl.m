//
//  UnlockTelemetryServiceImpl.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/10.
//

#import "UnlockTelemetryServiceImpl.h"
#import "Router.h"

static NSString * const kUnlockTelemetryEventsKey = @"unlock_telemetry_recent_events";
static NSString * const kUnlockTelemetryPowerMetricsKey = @"unlock_telemetry_power_metrics";
static NSUInteger const kUnlockTelemetryLimit = 100;

@implementation UnlockTelemetryServiceImpl

+ (void)load {
    [[Router shared] registerProtocol:@protocol(UnlockTelemetryService) impl:[self class]];
}

- (void)trackEvent:(NSString *)event attributes:(NSDictionary<NSString *,id> *)attributes {
    NSDictionary *payload = @{
        @"event" : event ?: @"unknown",
        @"attributes" : attributes ?: @{},
        @"timestamp" : @([[NSDate date] timeIntervalSince1970])
    };

    NSLog(@"[UnlockTelemetry] %@", payload);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *stored = [defaults arrayForKey:kUnlockTelemetryEventsKey] ?: @[];
    NSMutableArray *mutable = [stored mutableCopy];
    [mutable addObject:payload];

    if (mutable.count > kUnlockTelemetryLimit) {
        NSRange range = NSMakeRange(mutable.count - kUnlockTelemetryLimit, kUnlockTelemetryLimit);
        mutable = [[mutable subarrayWithRange:range] mutableCopy];
    }

    [defaults setObject:mutable.copy forKey:kUnlockTelemetryEventsKey];
}

- (void)incrementMetric:(NSString *)metricKey delta:(double)delta {
    NSMutableDictionary *metrics = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:kUnlockTelemetryPowerMetricsKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    double currentValue = [metrics[metricKey] doubleValue];
    metrics[metricKey] = @(currentValue + delta);
    metrics[@"last_updated_at"] = @([[NSDate date] timeIntervalSince1970]);
    [[NSUserDefaults standardUserDefaults] setObject:metrics.copy forKey:kUnlockTelemetryPowerMetricsKey];
}

- (void)accumulateDurationMetric:(NSString *)metricKey seconds:(NSTimeInterval)seconds {
    if (seconds <= 0) {
        return;
    }
    [self incrementMetric:metricKey delta:seconds];
}

- (NSDictionary<NSString *,id> *)currentPowerMetricsSnapshot {
    return [[NSUserDefaults standardUserDefaults] dictionaryForKey:kUnlockTelemetryPowerMetricsKey] ?: @{};
}

@end
