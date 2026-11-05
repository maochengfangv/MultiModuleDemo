# Performance 模块

## 1. 模块定位

统一收口客户端性能监控能力，遵循项目 `Protocol -> Impl -> Router` 约定：业务只依赖 `PerformanceService` 协议，不直接引用实现类。

```text
Performance/
├── PerformanceService.h            # 对外能力协议（Router 契约）
├── PerformanceServiceImpl.h/.m     # 实现 + 单例 + +load 自动注册
├── PerformanceMonitorConfig.h/.m   # 监控开关与阈值配置
└── PerformanceMetricKitSubscriber.h/.m  # MetricKit 订阅器
```

## 2. 核心 API

### 2.1 监控生命周期

| 方法 | 说明 |
| --- | --- |
| `- (void)startMonitoring;` | 按默认配置启动 |
| `- (void)startMonitoringWithConfig:` | 按自定义配置启动 |
| `- (void)stopMonitoring;` | 停止并释放 observer/timer/displayLink |

### 2.2 业务埋点

| 方法 | 说明 |
| --- | --- |
| `- (void)beginTrace:(NSString *)traceName;` | 开始链路耗时统计 |
| `- (void)endTrace:(NSString *)traceName;` | 结束并判定是否 `slow` |
| `- (void)recordTrace:duration:attributes:` | 直接记录已知耗时 |

### 2.3 数据读取

| 方法 | 说明 |
| --- | --- |
| `- (NSDictionary *)currentSnapshot;` | 实时快照（FPS、白屏占比、RunLoop 状态） |
| `- (NSArray *)recentEvents;` | 内存中最近事件（上限 100） |

### 2.4 事件通知

主线程发出 `PerformanceDidCaptureEventNotification`：

- `PerformanceEventNameKey`：事件名
- `PerformanceEventAttributesKey`：属性字典

## 3. 配置项（PerformanceMonitorConfig）

| 属性 | 默认值 | 含义 |
| --- | --- | --- |
| `fpsMonitorEnabled` | YES | FPS 监控开关 |
| `runLoopStallMonitorEnabled` | YES | 主线程卡顿监控开关 |
| `metricKitEnabled` | YES | MetricKit 订阅开关 |
| `businessTraceEnabled` | YES | 业务埋点开关 |
| `whiteScreenMonitorEnabled` | YES | 白屏监控开关 |
| `fpsSampleInterval` | 2.0 | FPS 统计窗口（秒） |
| `lowFPSThreshold` | 55.0 | 低 FPS 阈值 |
| `lowFPSContinuousCount` | 2 | 连续命中次数 |
| `runLoopStallThreshold` | 0.3 | 卡顿阈值（秒） |
| `watchdogInterval` | 0.05 | 卡顿检测间隔（秒） |
| `businessTraceSlowThreshold` | 1.0 | 慢链路阈值（秒） |
| `whiteScreenSampleInterval` | 2.0 | 白屏采样间隔（秒） |
| `whiteScreenRatioThreshold` | 0.95 | 白色像素占比阈值 |

## 4. 使用方式

### 4.1 通过 Router 启动监控

```objective-c
#import "Router.h"
#import "PerformanceService.h"

id<PerformanceService> perf = [[Router shared] sericeForProtocol:@protocol(PerformanceService)];
[perf startMonitoring];
```

### 4.2 自定义配置

```objective-c
PerformanceMonitorConfig *config = [PerformanceMonitorConfig defaultConfig];
config.whiteScreenRatioThreshold = 0.98;
config.lowFPSThreshold = 50.0;
[perf startMonitoringWithConfig:config];
```

### 4.3 业务埋点

```objective-c
[perf beginTrace:@"home_first_screen"];
// ... 首屏渲染逻辑
[perf endTrace:@"home_first_screen"];

[perf recordTrace:@"image_decode" duration:0.35 attributes:@{@"count": @(12)}];
```

### 4.4 读取快照与订阅事件

```objective-c
NSDictionary *snapshot = [perf currentSnapshot];
// snapshot[@"latest_fps"]
// snapshot[@"latest_white_screen_ratio"]
// snapshot[@"latest_runloop_activity"]

[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(handlePerfEvent:)
                                             name:PerformanceDidCaptureEventNotification
                                           object:nil];

- (void)handlePerfEvent:(NSNotification *)note {
    NSString *name = note.userInfo[PerformanceEventNameKey];
    NSDictionary *attrs = note.userInfo[PerformanceEventAttributesKey];
}
```

## 5. 上报事件清单

| 事件名 | 触发条件 |
| --- | --- |
| `performance_monitor_started` / `_stopped` | 监控启停 |
| `low_fps_detected` | 连续低 FPS 达到阈值 |
| `main_thread_stall_detected` | 主线程阻塞超过阈值 |
| `white_screen_detected` | 白色像素占比超过阈值 |
| `business_trace_finished` / `business_trace_missing_begin` | 埋点结束 / 缺少 begin |
| `system_metric_payload` | MetricKit 回调数据 |

## 6. 使用约束

- 必须通过 `Router` 获取协议实例，不要直接 `new` 实现类或跨模块 import `PerformanceServiceImpl.h`。
- `startMonitoring` 具备幂等保护，重复调用不会重复挂载 observer/timer。
- 事件同时写入内存环形缓冲与 `NSUserDefaults`（key: `performance_recent_events`），注意长期运行存储占用。
- 白屏采样在主线程执行 `renderInContext:`，属被动低频（默认 2s）策略，页面增多时需评估主线程开销。