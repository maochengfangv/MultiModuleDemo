//
//  PerformanceServiceImpl.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/11/5.
//

#import "PerformanceServiceImpl.h"
#import "PerformanceMonitorConfig.h"
#import "PerformanceMetricKitSubscriber.h"
#import "Router.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

NSNotificationName const PerformanceDidCaptureEventNotification = @"PerformanceDidCaptureEventNotification";
NSString * const PerformanceEventNameKey = @"PerformanceEventNameKey";
NSString * const PerformanceEventAttributesKey = @"PerformanceEventAttributesKey";

static NSUInteger const kPerformanceRecentEventLimit = 100;
static NSString * const kPerformanceRecentEventsKey = @"performance_recent_events";

@interface PerformanceServiceImpl ()

@property (nonatomic, strong) PerformanceMonitorConfig *config;
@property (nonatomic, assign) BOOL monitoring;

@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CFTimeInterval fpsWindowStartTime;
@property (nonatomic, assign) NSUInteger fpsFrameCount;
@property (nonatomic, assign) NSUInteger continuousLowFPSCount;
@property (nonatomic, assign) double latestFPS;

@property (nonatomic, assign) CFRunLoopObserverRef runLoopObserver;
@property (nonatomic, assign) CFRunLoopActivity latestRunLoopActivity;
@property (atomic, assign) CFTimeInterval latestRunLoopTimestamp;
@property (nonatomic, strong) dispatch_source_t watchdogTimer;
@property (nonatomic, assign) BOOL stallReporting;

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *traceStartTimes;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *memoryEvents;

@property (nonatomic, strong) dispatch_source_t whiteScreenTimer;
@property (nonatomic, assign) BOOL whiteScreenReporting;
@property (nonatomic, assign) double latestWhiteScreenRatio;

@end

@implementation PerformanceServiceImpl

+ (void)load {
    [[Router shared] registerProtocol:@protocol(PerformanceService) impl:[self class]];
}

+ (instancetype)sharedInstance {
    static PerformanceServiceImpl *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _config = [PerformanceMonitorConfig defaultConfig];
        _traceStartTimes = [NSMutableDictionary dictionary];
        _memoryEvents = [NSMutableArray array];
        _latestRunLoopTimestamp = CACurrentMediaTime();
    }
    return self;
}

- (void)startMonitoring {
    [self startMonitoringWithConfig:nil];
}

- (void)startMonitoringWithConfig:(PerformanceMonitorConfig *)config {
    if (self.monitoring) {
        return;
    }

    self.config = config ?: [PerformanceMonitorConfig defaultConfig];
    self.monitoring = YES;

    if (self.config.fpsMonitorEnabled) {
        [self startFPSMonitor];
    }

    if (self.config.runLoopStallMonitorEnabled) {
        [self startRunLoopStallMonitor];
    }

    if (self.config.metricKitEnabled) {
        __weak typeof(self) weakSelf = self;
        [[PerformanceMetricKitSubscriber sharedInstance] startWithPayloadHandler:^(NSDictionary<NSString *,id> *payload) {
            [weakSelf captureEvent:@"system_metric_payload" attributes:payload];
        }];
    }

    if (self.config.whiteScreenMonitorEnabled) {
        [self startWhiteScreenMonitor];
    }

    [self captureEvent:@"performance_monitor_started" attributes:@{
        @"fps_enabled": @(self.config.fpsMonitorEnabled),
        @"runloop_enabled": @(self.config.runLoopStallMonitorEnabled),
        @"metric_kit_enabled": @(self.config.metricKitEnabled),
        @"business_trace_enabled": @(self.config.businessTraceEnabled),
        @"white_screen_enabled": @(self.config.whiteScreenMonitorEnabled)
    }];
}

- (void)stopMonitoring {
    if (!self.monitoring) {
        return;
    }

    self.monitoring = NO;
    [self stopFPSMonitor];
    [self stopRunLoopStallMonitor];
    [self stopWhiteScreenMonitor];
    [[PerformanceMetricKitSubscriber sharedInstance] stop];

    [self captureEvent:@"performance_monitor_stopped" attributes:@{}];
}

#pragma mark - FPS

- (void)startFPSMonitor {
    if (self.displayLink) {
        return;
    }

    self.fpsWindowStartTime = CACurrentMediaTime();
    self.fpsFrameCount = 0;
    self.continuousLowFPSCount = 0;

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleDisplayLink:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopFPSMonitor {
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)handleDisplayLink:(CADisplayLink *)displayLink {
    self.fpsFrameCount += 1;

    CFTimeInterval now = CACurrentMediaTime();
    CFTimeInterval duration = now - self.fpsWindowStartTime;
    if (duration < self.config.fpsSampleInterval) {
        return;
    }

    double fps = self.fpsFrameCount / duration;
    self.latestFPS = fps;

    if (fps < self.config.lowFPSThreshold) {
        self.continuousLowFPSCount += 1;
    } else {
        self.continuousLowFPSCount = 0;
    }

    if (self.continuousLowFPSCount >= self.config.lowFPSContinuousCount) {
        [self captureEvent:@"low_fps_detected" attributes:@{
            @"fps": @(fps),
            @"threshold": @(self.config.lowFPSThreshold),
            @"duration": @(duration),
            @"continuous_count": @(self.continuousLowFPSCount)
        }];
    }

    self.fpsWindowStartTime = now;
    self.fpsFrameCount = 0;
}

#pragma mark - RunLoop

- (void)startRunLoopStallMonitor {
    if (self.runLoopObserver) {
        return;
    }

    CFRunLoopObserverContext context = {0, (__bridge void *)self, NULL, NULL, NULL};
    self.runLoopObserver = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                                   kCFRunLoopAllActivities,
                                                   YES,
                                                   NSIntegerMax,
                                                   PerformanceRunLoopObserverCallback,
                                                   &context);

    CFRunLoopAddObserver(CFRunLoopGetMain(), self.runLoopObserver, kCFRunLoopCommonModes);
    [self startWatchdogTimer];
}

- (void)stopRunLoopStallMonitor {
    if (self.runLoopObserver) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), self.runLoopObserver, kCFRunLoopCommonModes);
        CFRelease(self.runLoopObserver);
        self.runLoopObserver = NULL;
    }

    if (self.watchdogTimer) {
        dispatch_source_cancel(self.watchdogTimer);
        self.watchdogTimer = nil;
    }

    self.stallReporting = NO;
}

static void PerformanceRunLoopObserverCallback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    PerformanceServiceImpl *service = (__bridge PerformanceServiceImpl *)info;
    service.latestRunLoopActivity = activity;
    service.latestRunLoopTimestamp = CACurrentMediaTime();

    if (activity == kCFRunLoopBeforeWaiting || activity == kCFRunLoopAfterWaiting) {
        service.stallReporting = NO;
    }
}

- (void)startWatchdogTimer {
    dispatch_queue_t queue = dispatch_queue_create("com.demo.performance.watchdog", DISPATCH_QUEUE_SERIAL);
    self.watchdogTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

    uint64_t interval = (uint64_t)(self.config.watchdogInterval * NSEC_PER_SEC);
    dispatch_source_set_timer(self.watchdogTimer,
                              dispatch_time(DISPATCH_TIME_NOW, interval),
                              interval,
                              (uint64_t)(0.01 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.watchdogTimer, ^{
        [weakSelf checkRunLoopStall];
    });

    dispatch_resume(self.watchdogTimer);
}

- (void)checkRunLoopStall {
    if (!self.monitoring || self.stallReporting) {
        return;
    }

    CFTimeInterval now = CACurrentMediaTime();
    CFTimeInterval blockedDuration = now - self.latestRunLoopTimestamp;
    if (blockedDuration < self.config.runLoopStallThreshold) {
        return;
    }

    self.stallReporting = YES;

    [self captureEvent:@"main_thread_stall_detected" attributes:@{
        @"duration": @(blockedDuration),
        @"threshold": @(self.config.runLoopStallThreshold),
        @"runloop_activity": [self stringFromRunLoopActivity:self.latestRunLoopActivity],
        @"stack_note": @"线上建议接入 BSBacktraceLogger / PLCrashReporter / KSCrash 采样主线程堆栈；Demo 模块默认只记录卡顿阶段与耗时，避免使用不安全的跨线程栈采样。"
    }];
}

- (NSString *)stringFromRunLoopActivity:(CFRunLoopActivity)activity {
    switch (activity) {
        case kCFRunLoopEntry:
            return @"kCFRunLoopEntry";
        case kCFRunLoopBeforeTimers:
            return @"kCFRunLoopBeforeTimers";
        case kCFRunLoopBeforeSources:
            return @"kCFRunLoopBeforeSources";
        case kCFRunLoopBeforeWaiting:
            return @"kCFRunLoopBeforeWaiting";
        case kCFRunLoopAfterWaiting:
            return @"kCFRunLoopAfterWaiting";
        case kCFRunLoopExit:
            return @"kCFRunLoopExit";
        default:
            return @"unknown";
    }
}

#pragma mark - White Screen

- (void)startWhiteScreenMonitor {
    if (self.whiteScreenTimer) {
        return;
    }

    uint64_t interval = (uint64_t)(self.config.whiteScreenSampleInterval * NSEC_PER_SEC);
    self.whiteScreenTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(self.whiteScreenTimer,
                              dispatch_time(DISPATCH_TIME_NOW, interval),
                              interval,
                              (uint64_t)(0.1 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.whiteScreenTimer, ^{
        [weakSelf checkWhiteScreenOnMainThread];
    });

    dispatch_resume(self.whiteScreenTimer);
}

- (void)stopWhiteScreenMonitor {
    if (self.whiteScreenTimer) {
        dispatch_source_cancel(self.whiteScreenTimer);
        self.whiteScreenTimer = nil;
    }
    self.whiteScreenReporting = NO;
}

- (void)checkWhiteScreenOnMainThread {
    if (!self.monitoring || self.whiteScreenReporting) {
        return;
    }

    UIWindow *window = [self currentKeyWindow];
    if (!window || window.hidden || CGRectIsEmpty(window.bounds)) {
        return;
    }

    double whiteRatio = [self whitePixelRatioForView:window];
    self.latestWhiteScreenRatio = whiteRatio;
    if (whiteRatio < self.config.whiteScreenRatioThreshold) {
        self.whiteScreenReporting = NO;
        return;
    }

    self.whiteScreenReporting = YES;
    [self captureEvent:@"white_screen_detected" attributes:@{
        @"white_ratio": @(whiteRatio),
        @"threshold": @(self.config.whiteScreenRatioThreshold),
        @"sample_interval": @(self.config.whiteScreenSampleInterval),
        @"root_view_controller": NSStringFromClass(window.rootViewController.class) ?: @"unknown"
    }];
}

#pragma mark - Business Trace

- (void)beginTrace:(NSString *)traceName {
    if (!self.config.businessTraceEnabled || traceName.length == 0) {
        return;
    }

    @synchronized (self.traceStartTimes) {
        self.traceStartTimes[traceName] = @(CACurrentMediaTime());
    }
}

- (void)endTrace:(NSString *)traceName {
    if (!self.config.businessTraceEnabled || traceName.length == 0) {
        return;
    }

    NSNumber *startTime = nil;
    @synchronized (self.traceStartTimes) {
        startTime = self.traceStartTimes[traceName];
        [self.traceStartTimes removeObjectForKey:traceName];
    }

    if (!startTime) {
        [self captureEvent:@"business_trace_missing_begin" attributes:@{
            @"trace": traceName
        }];
        return;
    }

    NSTimeInterval duration = CACurrentMediaTime() - startTime.doubleValue;
    [self recordTrace:traceName duration:duration attributes:nil];
}

- (void)recordTrace:(NSString *)traceName duration:(NSTimeInterval)duration attributes:(NSDictionary<NSString *,id> *)attributes {
    if (!self.config.businessTraceEnabled || traceName.length == 0) {
        return;
    }

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"trace"] = traceName;
    payload[@"duration"] = @(duration);
    payload[@"slow"] = @(duration >= self.config.businessTraceSlowThreshold);
    payload[@"threshold"] = @(self.config.businessTraceSlowThreshold);

    if (attributes.count > 0) {
        payload[@"attributes"] = attributes;
    }

    [self captureEvent:@"business_trace_finished" attributes:payload.copy];
}

#pragma mark - White Screen Helpers

- (UIWindow *)currentKeyWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }
        }
    }

    return UIApplication.sharedApplication.keyWindow;
}

- (double)whitePixelRatioForView:(UIView *)view {
    // 以当前 view 的 bounds 作为白屏采样区域，避免直接使用屏幕尺寸导致弹窗、分屏、容器视图场景下统计范围失真。
    CGSize viewSize = view.bounds.size;
    // 前置防御：view 尚未完成布局或尺寸异常时不做截图采样，避免除零、空图和无意义的白屏误报。
    if (viewSize.width <= 0 || viewSize.height <= 0) {
        return 0;
    }

    // MVP 采用低分辨率缩略采样：将采样宽度压缩到 40px，在保证趋势判断有效的同时降低截图和像素遍历开销。
    CGFloat maxWidth = 40.0;
    CGFloat scale = maxWidth / MAX(viewSize.width, 1.0);
    CGSize sampleSize = CGSizeMake(maxWidth, MAX(1.0, floor(viewSize.height * scale)));

    // 将当前 view 的 layer 渲染到离屏 bitmap 中，得到用于像素分析的缩略截图。
    UIGraphicsBeginImageContextWithOptions(sampleSize, YES, 1.0);
    CGContextRef drawContext = UIGraphicsGetCurrentContext();
    // 缩放 CGContext 坐标系，确保完整 view 内容按比例映射到 sampleSize，而不是只截取左上角区域。
    CGContextScaleCTM(drawContext, sampleSize.width / viewSize.width, sampleSize.height / viewSize.height);
    [view.layer renderInContext:drawContext];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    CGImageRef imageRef = image.CGImage;
    if (!imageRef) {
        return 0;
    }

    // 将 CGImage 解码到 RGBA 原始像素缓冲区，后续按像素读取 RGB 分量计算白色占比。
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = width * bytesPerPixel;
    NSUInteger byteCount = bytesPerRow * height;
    unsigned char *rawData = calloc(byteCount, sizeof(unsigned char));
    if (!rawData) {
        return 0;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(rawData, width, height, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        free(rawData);
        return 0;
    }

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    NSUInteger whitePixelCount = 0;
    NSUInteger totalPixelCount = width * height;
    for (NSUInteger index = 0; index < totalPixelCount; index++) {
        NSUInteger offset = index * bytesPerPixel;
        // 白屏 MVP 的核心判定：RGB 三通道都接近纯白时计为白色像素，245 阈值用于容忍抗锯齿、透明混合和压缩误差。
        BOOL isWhite = rawData[offset] >= 245 && rawData[offset + 1] >= 245 && rawData[offset + 2] >= 245;
        if (isWhite) {
            whitePixelCount += 1;
        }
    }

    CGContextRelease(context);
    free(rawData);
    // 返回白色像素占比，由上层与 whiteScreenRatioThreshold 比较后决定是否上报 white_screen_detected。
    return totalPixelCount == 0 ? 0 : (double)whitePixelCount / (double)totalPixelCount;
}

#pragma mark - Snapshot

- (NSDictionary<NSString *,id> *)currentSnapshot {
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    snapshot[@"monitoring"] = @(self.monitoring);
    snapshot[@"latest_fps"] = @(self.latestFPS);
    snapshot[@"latest_white_screen_ratio"] = @(self.latestWhiteScreenRatio);
    snapshot[@"latest_runloop_activity"] = [self stringFromRunLoopActivity:self.latestRunLoopActivity];
    snapshot[@"latest_runloop_timestamp"] = @(self.latestRunLoopTimestamp);
    snapshot[@"recent_event_count"] = @(self.memoryEvents.count);
    return snapshot.copy;
}

- (NSArray<NSDictionary<NSString *,id> *> *)recentEvents {
    @synchronized (self.memoryEvents) {
        return self.memoryEvents.copy;
    }
}

#pragma mark - Event Sink

- (void)captureEvent:(NSString *)event attributes:(NSDictionary<NSString *,id> *)attributes {
    NSDictionary *payload = @{
        @"event": event ?: @"unknown",
        @"attributes": attributes ?: @{},
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };

    NSLog(@"[Performance] %@", payload);

    @synchronized (self.memoryEvents) {
        [self.memoryEvents addObject:payload];
        if (self.memoryEvents.count > kPerformanceRecentEventLimit) {
            [self.memoryEvents removeObjectAtIndex:0];
        }
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *stored = [defaults arrayForKey:kPerformanceRecentEventsKey] ?: @[];
    NSMutableArray *mutable = [stored mutableCopy];
    [mutable addObject:payload];

    if (mutable.count > kPerformanceRecentEventLimit) {
        NSRange range = NSMakeRange(mutable.count - kPerformanceRecentEventLimit, kPerformanceRecentEventLimit);
        mutable = [[mutable subarrayWithRange:range] mutableCopy];
    }

    [defaults setObject:mutable.copy forKey:kPerformanceRecentEventsKey];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PerformanceDidCaptureEventNotification
                                                            object:self
                                                          userInfo:@{
            PerformanceEventNameKey: event ?: @"unknown",
            PerformanceEventAttributesKey: attributes ?: @{}
        }];
    });
}

@end
