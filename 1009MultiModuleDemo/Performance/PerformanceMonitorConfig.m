//
//  PerformanceMonitorConfig.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/11/5.
//

#import "PerformanceMonitorConfig.h"

@implementation PerformanceMonitorConfig

+ (instancetype)defaultConfig {
    PerformanceMonitorConfig *config = [[PerformanceMonitorConfig alloc] init];
    config.fpsMonitorEnabled = YES;
    config.runLoopStallMonitorEnabled = YES;
    config.metricKitEnabled = YES;
    config.businessTraceEnabled = YES;
    config.whiteScreenMonitorEnabled = YES;
    config.fpsSampleInterval = 2.0;
    config.lowFPSThreshold = 55.0;
    config.lowFPSContinuousCount = 2;
    config.runLoopStallThreshold = 0.3;
    config.watchdogInterval = 0.05;
    config.businessTraceSlowThreshold = 1.0;
    config.whiteScreenSampleInterval = 2.0;
    config.whiteScreenRatioThreshold = 0.95;
    return config;
}

@end
