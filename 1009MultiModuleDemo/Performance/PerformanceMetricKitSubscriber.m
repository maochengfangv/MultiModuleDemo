//
//  PerformanceMetricKitSubscriber.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/11/5.
//

#import "PerformanceMetricKitSubscriber.h"

#if __has_include(<MetricKit/MetricKit.h>)
#import <MetricKit/MetricKit.h>
#endif

@interface PerformanceMetricKitSubscriber ()
#if __has_include(<MetricKit/MetricKit.h>)
<MXMetricManagerSubscriber>
#endif

@property (nonatomic, copy) PerformanceMetricKitPayloadHandler payloadHandler;
@property (nonatomic, assign) BOOL started;

@end

@implementation PerformanceMetricKitSubscriber

+ (instancetype)sharedInstance {
    static PerformanceMetricKitSubscriber *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PerformanceMetricKitSubscriber alloc] init];
    });
    return instance;
}

- (void)startWithPayloadHandler:(PerformanceMetricKitPayloadHandler)handler {
    self.payloadHandler = handler;
    if (self.started) {
        return;
    }

#if __has_include(<MetricKit/MetricKit.h>)
    if (@available(iOS 13.0, *)) {
        [[MXMetricManager sharedManager] addSubscriber:self];
        self.started = YES;
    }
#endif
}

- (void)stop {
    if (!self.started) {
        return;
    }

#if __has_include(<MetricKit/MetricKit.h>)
    if (@available(iOS 13.0, *)) {
        [[MXMetricManager sharedManager] removeSubscriber:self];
    }
#endif

    self.started = NO;
    self.payloadHandler = nil;
}

#if __has_include(<MetricKit/MetricKit.h>)
- (void)didReceiveMetricPayloads:(NSArray<MXMetricPayload *> *)payloads API_AVAILABLE(ios(13.0)) {
    if (!self.payloadHandler) {
        return;
    }

    for (MXMetricPayload *payload in payloads) {
        NSMutableDictionary *event = [NSMutableDictionary dictionary];
        event[@"type"] = @"metric_kit_metric_payload";
        event[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);

        NSData *jsonData = payload.JSONRepresentation;
        if (jsonData) {
            id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            if (jsonObject) {
                event[@"payload"] = jsonObject;
            }
        }

        self.payloadHandler(event.copy);
    }
}

- (void)didReceiveDiagnosticPayloads:(NSArray<MXDiagnosticPayload *> *)payloads API_AVAILABLE(ios(14.0)) {
    if (!self.payloadHandler) {
        return;
    }

    for (MXDiagnosticPayload *payload in payloads) {
        NSMutableDictionary *event = [NSMutableDictionary dictionary];
        event[@"type"] = @"metric_kit_diagnostic_payload";
        event[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);

        NSData *jsonData = payload.JSONRepresentation;
        if (jsonData) {
            id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            if (jsonObject) {
                event[@"payload"] = jsonObject;
            }
        }

        self.payloadHandler(event.copy);
    }
}
#endif

@end
