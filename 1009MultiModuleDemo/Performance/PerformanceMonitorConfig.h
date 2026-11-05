//
//  PerformanceMonitorConfig.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/11/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PerformanceMonitorConfig : NSObject

@property (nonatomic, assign) BOOL fpsMonitorEnabled;
@property (nonatomic, assign) BOOL runLoopStallMonitorEnabled;
@property (nonatomic, assign) BOOL metricKitEnabled;
@property (nonatomic, assign) BOOL businessTraceEnabled;
@property (nonatomic, assign) BOOL whiteScreenMonitorEnabled;

/// FPS 统计窗口，默认 2 秒
@property (nonatomic, assign) NSTimeInterval fpsSampleInterval;

/// 低 FPS 阈值，默认 55
@property (nonatomic, assign) double lowFPSThreshold;

/// 连续低 FPS 命中次数，默认 2
@property (nonatomic, assign) NSUInteger lowFPSContinuousCount;

/// RunLoop 卡顿阈值，默认 0.3 秒
@property (nonatomic, assign) NSTimeInterval runLoopStallThreshold;

/// RunLoop Watchdog 检查间隔，默认 0.05 秒
@property (nonatomic, assign) NSTimeInterval watchdogInterval;

/// 单个业务 Trace 最大容忍耗时，默认 1 秒
@property (nonatomic, assign) NSTimeInterval businessTraceSlowThreshold;

/// 白屏检测采样间隔，默认 2 秒
@property (nonatomic, assign) NSTimeInterval whiteScreenSampleInterval;

/// 判定白屏的白色像素占比阈值，默认 0.95
@property (nonatomic, assign) double whiteScreenRatioThreshold;

+ (instancetype)defaultConfig;

@end

NS_ASSUME_NONNULL_END
