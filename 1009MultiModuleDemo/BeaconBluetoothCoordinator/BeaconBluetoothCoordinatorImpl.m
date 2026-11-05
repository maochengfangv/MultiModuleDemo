//
//  BeaconBluetoothCoordinatorImpl.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/10.
//

#import "BeaconBluetoothCoordinatorImpl.h"
#import "Router.h"
#import "IBeaconService.h"
#import "BluetoothService.h"
#import "LoginService.h"
#import "VehicleAccessService.h"
#import "UnlockTelemetryService.h"

NSNotificationName const BeaconBluetoothCoordinatorStateDidChangeNotification = @"BeaconBluetoothCoordinatorStateDidChangeNotification";
NSString * const BeaconBluetoothCoordinatorBeaconStatusKey = @"BeaconBluetoothCoordinatorBeaconStatusKey";
NSString * const BeaconBluetoothCoordinatorBluetoothStatusKey = @"BeaconBluetoothCoordinatorBluetoothStatusKey";
NSString * const BeaconBluetoothCoordinatorDevicesKey = @"BeaconBluetoothCoordinatorDevicesKey";
NSString * const BeaconBluetoothCoordinatorAudioStatusKey = @"BeaconBluetoothCoordinatorAudioStatusKey";

typedef NS_ENUM(NSUInteger, BeaconBluetoothFlowState) {
    BeaconBluetoothFlowStateIdle,
    BeaconBluetoothFlowStateBeaconCandidate,
    BeaconBluetoothFlowStateScanning,
    BeaconBluetoothFlowStateConnecting,
    BeaconBluetoothFlowStateConnected,
    BeaconBluetoothFlowStateUnlocking,
    BeaconBluetoothFlowStateCooldown,
};

static NSTimeInterval const kInsideDebounce = 2.0;
static NSTimeInterval const kOutsideGrace = 10.0;
static NSTimeInterval const kScanTimeout = 8.0;
static NSTimeInterval const kCooldown = 15.0;

@interface BeaconBluetoothCoordinatorImpl () <IBeaconServiceDelegate, BluetoothServiceDelegate>

@property (nonatomic, strong) id<IBeaconService> beaconService;
@property (nonatomic, strong) id<BluetoothService> bluetoothService;
@property (nonatomic, strong) id<LoginService> loginService;
@property (nonatomic, strong) id<VehicleAccessService> vehicleAccessService;
@property (nonatomic, strong) id<UnlockTelemetryService> telemetryService;
@property (nonatomic, copy) NSString *beaconStatus;
@property (nonatomic, copy) NSString *bluetoothStatus;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *> *devices;
@property (nonatomic, copy) NSString *audioStatus;
@property (nonatomic, strong) NSDictionary<NSString *, id> *audioMetrics;
@property (nonatomic, assign) BeaconBluetoothFlowState flowState;
@property (nonatomic, assign) BOOL beaconInside;
@property (nonatomic, assign) BOOL bootstrapped;
@property (nonatomic, copy) dispatch_block_t insideDebounceBlock;
@property (nonatomic, copy) dispatch_block_t outsideGraceBlock;
@property (nonatomic, copy) dispatch_block_t scanTimeoutBlock;
@property (nonatomic, copy) dispatch_block_t cooldownBlock;
@property (nonatomic, strong) NSDate *scanStartedAt;
@property (nonatomic, strong) NSDate *connectStartedAt;
@property (nonatomic, strong) NSDate *connectedAt;

- (instancetype)initSingleton;
- (void)transitionToState:(BeaconBluetoothFlowState)state bluetoothStatus:(NSString *)status;
- (void)armInsideDebounceWithStatus:(NSString *)status;
- (void)armOutsideGrace;
- (void)scheduleScanTimeout;
- (void)enterCooldownWithReason:(NSString *)reason;
- (void)cancelPendingBlocks;
- (BOOL)hasAutoUnlockEligibility;
- (NSUInteger)connectableCountInDevices;
- (nullable NSDictionary<NSString *, NSString *> *)preferredAuthorizedDeviceFromDevices;
- (void)trackEvent:(NSString *)event attributes:(NSDictionary<NSString *, id> *)attributes;
- (void)flushPowerMetricsForStateTransitionFrom:(BeaconBluetoothFlowState)fromState to:(BeaconBluetoothFlowState)toState;

@end

@implementation BeaconBluetoothCoordinatorImpl

+ (void)load {
    [[Router shared] registerProtocol:@protocol(BeaconBluetoothCoordinator) impl:[self class]];
}

+ (instancetype)sharedInstance {
    static BeaconBluetoothCoordinatorImpl *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] initSingleton];
    });
    return instance;
}

- (instancetype)initSingleton {
    self = [super init];
    if (self) {
        _devices = @[];
        _beaconStatus = @"iBeacon: 等待初始化";
        _bluetoothStatus = @"蓝牙: 等待初始化";
        _audioStatus = @"音频流: 等待连接设备";
        _audioMetrics = @{};
        _flowState = BeaconBluetoothFlowStateIdle;
    }
    return self;
}

- (void)bootstrapWithLaunchOptions:(NSDictionary *)launchOptions {
    if (self.bootstrapped) {
        return;
    }

    self.bootstrapped = YES;
    self.beaconService = [[Router shared] sericeForProtocol:@protocol(IBeaconService)];
    self.bluetoothService = [[Router shared] sericeForProtocol:@protocol(BluetoothService)];
    self.loginService = [[Router shared] sericeForProtocol:@protocol(LoginService)];
    self.vehicleAccessService = [[Router shared] sericeForProtocol:@protocol(VehicleAccessService)];
    self.telemetryService = [[Router shared] sericeForProtocol:@protocol(UnlockTelemetryService)];

    self.beaconService.delegate = self;
    self.bluetoothService.delegate = self;
    [self.bluetoothService configurePreferredServiceUUIDString:nil
                               writeCharacteristicUUIDString:nil
                              notifyCharacteristicUUIDString:nil];

    [self.beaconService bootstrapWithLaunchOptions:launchOptions];
    [self.bluetoothService bootstrapWithLaunchOptions:launchOptions];
    [self postStateDidChange];
}

- (void)requestLocationAuthorizationAndStartMonitoring {
    if (!self.bootstrapped) {
        [self bootstrapWithLaunchOptions:nil];
    }
    [self.beaconService requestAlwaysAuthorization];
    [self.beaconService startMonitoring];
    self.beaconStatus = [NSString stringWithFormat:@"iBeacon: %@", [self.beaconService currentRegionDescription]];
    [self postStateDidChange];
}

- (void)toggleManualScan {
    self.beaconInside = NO;
    [self cancelPendingBlocks];

    if ([self.bluetoothService isScanning]) {
        [self.bluetoothService stopScan];
        [self transitionToState:BeaconBluetoothFlowStateIdle bluetoothStatus:@"蓝牙: 已停止手动扫描"];
        return;
    }

    self.devices = @[];
    [self.bluetoothService startScan];
    [self transitionToState:BeaconBluetoothFlowStateScanning bluetoothStatus:@"蓝牙: 手动扫描中"];
    [self scheduleScanTimeout];
}

- (void)connectDeviceWithIdentifier:(NSUUID *)identifier {
    self.beaconInside = NO;
    [self cancelPendingBlocks];
    [self.bluetoothService connectPeripheralWithIdentifier:identifier];
    [self transitionToState:BeaconBluetoothFlowStateConnecting bluetoothStatus:@"蓝牙: 手动发起连接"];
}

- (void)sendHexCommand:(NSString *)hexCommand {
    if (self.flowState != BeaconBluetoothFlowStateConnected && self.flowState != BeaconBluetoothFlowStateUnlocking) {
        [self trackEvent:@"unlock_command_rejected" attributes:@{ @"reason": @"not_connected" }];
        [self transitionToState:self.flowState bluetoothStatus:@"蓝牙: 未连接完成，拒绝发送指令"];
        return;
    }
    [self trackEvent:@"unlock_command_sent" attributes:@{ @"length": @(hexCommand.length) }];
    [self transitionToState:BeaconBluetoothFlowStateUnlocking bluetoothStatus:@"蓝牙: 正在发送解锁指令"];
    [self.bluetoothService sendHexCommand:hexCommand];
}

- (void)toggleMockAudioStreaming {
    if ([self.bluetoothService isStreamingAudio]) {
        [self.bluetoothService stopMockAudioStreaming];
        self.audioStatus = @"音频流: 已请求停止 Mock 音频流";
    } else {
        [self.bluetoothService startMockAudioStreaming];
        self.audioStatus = @"音频流: 已请求启动 Mock 音频流";
    }
    [self postStateDidChange];
}

- (BOOL)isScanning {
    return [self.bluetoothService isScanning];
}

- (BOOL)isStreamingAudio {
    return [self.bluetoothService isStreamingAudio];
}

- (NSArray<NSDictionary<NSString *,NSString *> *> *)currentDevices {
    return self.devices;
}

- (NSString *)currentBeaconStatus {
    return self.beaconStatus;
}

- (NSString *)currentBluetoothStatus {
    return self.bluetoothStatus;
}

- (NSString *)currentAudioStatus {
    return self.audioStatus;
}

#pragma mark - IBeaconServiceDelegate

- (void)iBeaconService:(id<IBeaconService>)service didUpdateStatusMessage:(NSString *)message {
    self.beaconStatus = [NSString stringWithFormat:@"iBeacon: %@", message];
    [self postStateDidChange];
}

- (void)iBeaconServiceDidEnterRegion:(id<IBeaconService>)service { [self.telemetryService incrementMetric:@"beacon_enter_count" delta:1]; self.beaconStatus = @"iBeacon: 进入目标区域，等待防抖确认"; [self armInsideDebounceWithStatus:@"蓝牙: 收到 iBeacon 进入事件，等待稳定"]; }
- (void)iBeaconServiceDidExitRegion:(id<IBeaconService>)service { [self.telemetryService incrementMetric:@"beacon_exit_count" delta:1]; self.beaconStatus = @"iBeacon: 离开事件到达，等待退出宽限"; [self armOutsideGrace]; }
- (void)iBeaconService:(id<IBeaconService>)service didDetermineState:(CLRegionState)state { if (state == CLRegionStateInside) { [self.telemetryService incrementMetric:@"beacon_inside_state_count" delta:1]; self.beaconStatus = @"iBeacon: 当前在目标区域内，等待防抖确认"; [self armInsideDebounceWithStatus:@"蓝牙: 区域内状态确认中"]; } else if (state == CLRegionStateOutside) { [self.telemetryService incrementMetric:@"beacon_outside_state_count" delta:1]; self.beaconStatus = @"iBeacon: 当前在目标区域外"; [self armOutsideGrace]; } else { [self postStateDidChange]; } }

#pragma mark - BluetoothServiceDelegate

- (void)bluetoothService:(id<BluetoothService>)service didUpdateStatusMessage:(NSString *)message { if ((self.flowState == BeaconBluetoothFlowStateConnecting || self.flowState == BeaconBluetoothFlowStateScanning || self.flowState == BeaconBluetoothFlowStateUnlocking) && ([message containsString:@"失败"] || [message containsString:@"不可用"] || [message containsString:@"超时"])) { [self enterCooldownWithReason:[NSString stringWithFormat:@"蓝牙: %@，进入冷却期", message]]; return; } self.bluetoothStatus = [NSString stringWithFormat:@"蓝牙: %@", message]; [self postStateDidChange]; }

- (void)bluetoothService:(id<BluetoothService>)service didDiscoverDeviceInfo:(NSDictionary<NSString *,NSString *> *)deviceInfo { NSMutableArray *m = [self.devices mutableCopy]; NSUInteger i = NSNotFound; for (NSUInteger idx = 0; idx < m.count; idx++) { if ([m[idx][@"identifier"] isEqualToString:deviceInfo[@"identifier"]]) { i = idx; break; } } if (i != NSNotFound) { [m replaceObjectAtIndex:i withObject:deviceInfo]; } else { [m addObject:deviceInfo]; } self.devices = m.copy; [self trackEvent:@"ble_device_discovered" attributes:@{ @"identifier": deviceInfo[@"identifier"] ?: @"", @"connectable": deviceInfo[@"isConnectable"] ?: @"NO" }]; [self postStateDidChange]; if (self.flowState != BeaconBluetoothFlowStateScanning || !self.beaconInside) { return; } NSUInteger c = [self connectableCountInDevices]; if (c > 1) { [self trackEvent:@"ble_auto_connect_rejected" attributes:@{ @"reason": @"multiple_connectable" }]; [self enterCooldownWithReason:@"蓝牙: 检测到多台可连接车辆，拒绝自动连接"]; return; } NSDictionary<NSString *, NSString *> *authorizedDevice = [self preferredAuthorizedDeviceFromDevices]; if (!authorizedDevice) { return; } NSString *identifier = authorizedDevice[@"identifier"]; if (identifier.length == 0) { return; } [self cancelPendingBlocks]; [self trackEvent:@"ble_auto_connect_start" attributes:@{ @"identifier": identifier }]; [self.bluetoothService connectPeripheralWithIdentifier:[[NSUUID alloc] initWithUUIDString:identifier]]; [self transitionToState:BeaconBluetoothFlowStateConnecting bluetoothStatus:[NSString stringWithFormat:@"蓝牙: 自动连接 %@", authorizedDevice[@"name"] ?: @"车辆设备"]]; }

- (void)bluetoothService:(id<BluetoothService>)service didConnectPeripheralNamed:(NSString *)name identifier:(NSUUID *)identifier { [self cancelPendingBlocks]; self.audioStatus = @"音频流: 设备已连接，可启动 Mock 流"; [self transitionToState:BeaconBluetoothFlowStateConnected bluetoothStatus:[NSString stringWithFormat:@"蓝牙: 已连接 %@，保持 GATT 通道", name]]; }
- (void)bluetoothService:(id<BluetoothService>)service didDisconnectPeripheralNamed:(NSString *)name identifier:(NSUUID *)identifier error:(NSError *)error { self.audioMetrics = @{}; self.audioStatus = @"音频流: 设备已断开"; if (self.beaconInside) { [self armInsideDebounceWithStatus:[NSString stringWithFormat:@"蓝牙: %@ 已断开，等待稳定后重试", name]]; return; } [self transitionToState:BeaconBluetoothFlowStateIdle bluetoothStatus:[NSString stringWithFormat:@"蓝牙: 已断开 %@", name]]; }
- (void)bluetoothService:(id<BluetoothService>)service didReceiveValue:(NSData *)data characteristicUUID:(NSString *)characteristicUUID { BeaconBluetoothFlowState next = self.flowState == BeaconBluetoothFlowStateUnlocking ? BeaconBluetoothFlowStateConnected : self.flowState; [self transitionToState:next bluetoothStatus:[NSString stringWithFormat:@"蓝牙: 收到 %@，长度=%lu", characteristicUUID, (unsigned long)data.length]]; }
- (void)bluetoothService:(id<BluetoothService>)service didReceiveAudioFrame:(NSData *)audioFrame metadata:(NSDictionary<NSString *,id> *)metadata { NSNumber *packetIndex = metadata[@"packetIndex"] ?: @0; self.audioStatus = [NSString stringWithFormat:@"音频流: 收到第 %@ 包，%lu bytes", packetIndex, (unsigned long)audioFrame.length]; [self postStateDidChange]; }
- (void)bluetoothService:(id<BluetoothService>)service didUpdateAudioStreamMetrics:(NSDictionary<NSString *,id> *)metrics { self.audioMetrics = metrics ?: @{}; NSNumber *packetCount = self.audioMetrics[@"packetCount"] ?: @0; NSNumber *durationMs = self.audioMetrics[@"durationMs"] ?: @0; NSNumber *totalBytes = self.audioMetrics[@"totalBytes"] ?: @0; self.audioStatus = [NSString stringWithFormat:@"音频流: %@ 包 / %@ ms / %@ bytes", packetCount, durationMs, totalBytes]; [self postStateDidChange]; }

#pragma mark - Private

- (void)transitionToState:(BeaconBluetoothFlowState)state bluetoothStatus:(NSString *)status { BeaconBluetoothFlowState previous = self.flowState; [self flushPowerMetricsForStateTransitionFrom:previous to:state]; self.flowState = state; self.bluetoothStatus = status; [self trackEvent:@"flow_state_changed" attributes:@{ @"from": @(previous), @"to": @(state), @"status": status ?: @"" }]; [self postStateDidChange]; }
- (void)armInsideDebounceWithStatus:(NSString *)status { self.beaconInside = YES; [self.telemetryService incrementMetric:@"beacon_trigger_count" delta:1]; if (![self hasAutoUnlockEligibility]) { [self enterCooldownWithReason:@"蓝牙: 当前账号不满足自动解锁条件"]; return; } if (self.flowState == BeaconBluetoothFlowStateConnecting || self.flowState == BeaconBluetoothFlowStateConnected || self.flowState == BeaconBluetoothFlowStateUnlocking) { [self.telemetryService incrementMetric:@"beacon_ignored_while_busy_count" delta:1]; [self transitionToState:self.flowState bluetoothStatus:@"蓝牙: 已有活动连接，忽略重复触发"]; return; } if (self.flowState == BeaconBluetoothFlowStateCooldown) { [self.telemetryService incrementMetric:@"beacon_trigger_during_cooldown_count" delta:1]; return; } if (self.outsideGraceBlock) { dispatch_block_cancel(self.outsideGraceBlock); self.outsideGraceBlock = nil; } [self transitionToState:BeaconBluetoothFlowStateBeaconCandidate bluetoothStatus:status]; dispatch_block_t block = dispatch_block_create(0, ^{ if (!self.beaconInside || self.flowState != BeaconBluetoothFlowStateBeaconCandidate) { return; } self.devices = @[]; [self.bluetoothService startScan]; [self transitionToState:BeaconBluetoothFlowStateScanning bluetoothStatus:@"蓝牙: 防抖完成，开始扫描车辆设备"]; [self scheduleScanTimeout]; }); self.insideDebounceBlock = block; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kInsideDebounce * NSEC_PER_SEC)), dispatch_get_main_queue(), block); }
- (void)armOutsideGrace { self.beaconInside = NO; if (self.insideDebounceBlock) { dispatch_block_cancel(self.insideDebounceBlock); self.insideDebounceBlock = nil; } dispatch_block_t block = dispatch_block_create(0, ^{ [self cancelPendingBlocks]; if ([self.bluetoothService isScanning]) { [self.bluetoothService stopScan]; } if ([self.bluetoothService isConnected]) { [self.bluetoothService disconnectCurrentPeripheral]; } [self transitionToState:BeaconBluetoothFlowStateIdle bluetoothStatus:@"蓝牙: 已离开 iBeacon 区域，停止连接流程"]; }); self.outsideGraceBlock = block; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kOutsideGrace * NSEC_PER_SEC)), dispatch_get_main_queue(), block); }
- (void)scheduleScanTimeout { dispatch_block_t block = dispatch_block_create(0, ^{ if (self.flowState == BeaconBluetoothFlowStateScanning) { [self enterCooldownWithReason:@"蓝牙: 扫描超时，进入冷却期"]; } }); self.scanTimeoutBlock = block; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kScanTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), block); }
- (void)enterCooldownWithReason:(NSString *)reason { [self cancelPendingBlocks]; if ([self.bluetoothService isScanning]) { [self.bluetoothService stopScan]; } [self.telemetryService incrementMetric:@"cooldown_count" delta:1]; [self trackEvent:@"flow_cooldown_entered" attributes:@{ @"reason": reason ?: @"" }]; self.flowState = BeaconBluetoothFlowStateCooldown; self.bluetoothStatus = reason; [self postStateDidChange]; dispatch_block_t block = dispatch_block_create(0, ^{ [self trackEvent:@"flow_cooldown_finished" attributes:@{ @"beaconInside": @(self.beaconInside) }]; if (self.beaconInside) { [self armInsideDebounceWithStatus:@"蓝牙: 冷却结束，重新评估连接"]; } else { [self transitionToState:BeaconBluetoothFlowStateIdle bluetoothStatus:@"蓝牙: 冷却结束，等待下一次触发"]; } }); self.cooldownBlock = block; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCooldown * NSEC_PER_SEC)), dispatch_get_main_queue(), block); }
- (void)cancelPendingBlocks { if (self.insideDebounceBlock) { dispatch_block_cancel(self.insideDebounceBlock); self.insideDebounceBlock = nil; } if (self.outsideGraceBlock) { dispatch_block_cancel(self.outsideGraceBlock); self.outsideGraceBlock = nil; } if (self.scanTimeoutBlock) { dispatch_block_cancel(self.scanTimeoutBlock); self.scanTimeoutBlock = nil; } if (self.cooldownBlock) { dispatch_block_cancel(self.cooldownBlock); self.cooldownBlock = nil; } }
- (BOOL)hasAutoUnlockEligibility { BOOL eligible = [self.loginService isLoggedIn]; if (!eligible) { [self trackEvent:@"auto_unlock_ineligible" attributes:@{ @"reason": @"not_logged_in" }]; } return eligible; }
- (NSUInteger)connectableCountInDevices { NSUInteger count = 0; for (NSDictionary *item in self.devices) { if ([item[@"isConnectable"] isEqualToString:@"YES"]) { count += 1; } } return count; }
- (NSDictionary<NSString *, NSString *> *)preferredAuthorizedDeviceFromDevices { NSString *reason = nil; NSDictionary<NSString *, NSString *> *device = [self.vehicleAccessService preferredAuthorizedDeviceFromCandidates:self.devices rejectionReason:&reason]; if (!device && reason.length > 0) { [self trackEvent:@"vehicle_access_rejected" attributes:@{ @"reason": reason }]; self.bluetoothStatus = [NSString stringWithFormat:@"蓝牙: %@", reason]; [self postStateDidChange]; } return device; }
- (void)trackEvent:(NSString *)event attributes:(NSDictionary<NSString *,id> *)attributes { [self.telemetryService trackEvent:event attributes:attributes]; }
- (void)flushPowerMetricsForStateTransitionFrom:(BeaconBluetoothFlowState)fromState to:(BeaconBluetoothFlowState)toState { NSDate *now = [NSDate date]; if (toState == BeaconBluetoothFlowStateScanning && fromState != BeaconBluetoothFlowStateScanning) { self.scanStartedAt = now; [self.telemetryService incrementMetric:@"scan_session_count" delta:1]; } if (fromState == BeaconBluetoothFlowStateScanning && toState != BeaconBluetoothFlowStateScanning && self.scanStartedAt) { [self.telemetryService accumulateDurationMetric:@"scan_duration_total" seconds:[now timeIntervalSinceDate:self.scanStartedAt]]; self.scanStartedAt = nil; } if (toState == BeaconBluetoothFlowStateConnecting && fromState != BeaconBluetoothFlowStateConnecting) { self.connectStartedAt = now; [self.telemetryService incrementMetric:@"connect_attempt_count" delta:1]; } if (toState == BeaconBluetoothFlowStateConnected && fromState != BeaconBluetoothFlowStateConnected) { [self.telemetryService incrementMetric:@"connect_success_count" delta:1]; if (self.connectStartedAt) { [self.telemetryService accumulateDurationMetric:@"connect_latency_total" seconds:[now timeIntervalSinceDate:self.connectStartedAt]]; self.connectStartedAt = nil; } self.connectedAt = now; } if (fromState == BeaconBluetoothFlowStateConnected && toState != BeaconBluetoothFlowStateConnected && self.connectedAt) { [self.telemetryService accumulateDurationMetric:@"connected_duration_total" seconds:[now timeIntervalSinceDate:self.connectedAt]]; self.connectedAt = nil; } if (toState == BeaconBluetoothFlowStateUnlocking && fromState != BeaconBluetoothFlowStateUnlocking) { [self.telemetryService incrementMetric:@"unlock_attempt_count" delta:1]; } }

- (void)postStateDidChange {
    NSDictionary *userInfo = @{
        BeaconBluetoothCoordinatorBeaconStatusKey : self.beaconStatus ?: @"",
        BeaconBluetoothCoordinatorBluetoothStatusKey : self.bluetoothStatus ?: @"",
        BeaconBluetoothCoordinatorDevicesKey : self.devices ?: @[],
        BeaconBluetoothCoordinatorAudioStatusKey : self.audioStatus ?: @""
    };

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:BeaconBluetoothCoordinatorStateDidChangeNotification
                                                            object:self
                                                          userInfo:userInfo];
    });
}

@end
