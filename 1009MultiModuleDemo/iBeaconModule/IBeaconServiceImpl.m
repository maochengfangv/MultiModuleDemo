//
//  IBeaconServiceImpl.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/9.
//

#import "IBeaconServiceImpl.h"
#import <UIKit/UIKit.h>
#import "Router.h"

static NSString * const kIBeaconRegionIdentifier = @"com.maocf.demo.vehicle.beacon";
static NSString * const kIBeaconUUIDString = @"E2C56DB5-DFFB-48D2-B060-D0F5A71096E0";
static NSString * const kIBeaconDesiredMonitoringKey = @"com.maocf.demo.ibeacon.desiredMonitoring";
static CLBeaconMajorValue const kIBeaconMajor = 100;
static CLBeaconMinorValue const kIBeaconMinor = 1;

@interface IBeaconServiceImpl ()<CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLBeaconRegion *beaconRegion;
@property (nonatomic, copy) NSString *lastStatusMessage;
@property (nonatomic, assign) BOOL desiredMonitoring;

- (instancetype)initSingleton;

@end

@implementation IBeaconServiceImpl

+ (void)load {
    [[Router shared] registerProtocol:@protocol(IBeaconService) impl:[self class]];
}

+ (instancetype)sharedInstance{
    static IBeaconServiceImpl *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] initSingleton];
    });
    
    return instance;
}

- (instancetype)initSingleton{
    self = [super init];
    if (self) {
        _desiredMonitoring = [[NSUserDefaults standardUserDefaults] boolForKey:kIBeaconDesiredMonitoringKey];
    }
    
    return self;
}

- (void)bootstrapWithLaunchOptions:(NSDictionary *)launchOptions{
    [self ensureLocationManager];
    if(launchOptions[UIApplicationLaunchOptionsLocationKey]){
        [self emitStatusMessage:@"App 由 location event 唤醒，正在恢复 iBeacon 监听链路。"];
    }
    
    if (self.desiredMonitoring){
        [self startMonitoring];
    }
}

- (void)requestAlwaysAuthorization{
    [self ensureLocationManager];
    [self.locationManager requestAlwaysAuthorization];
    [self emitStatusMessage:@"已发起 Always Location 权限申请。"];
}

- (void)startMonitoring{
    [self ensureLocationManager];
    self.desiredMonitoring = YES;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kIBeaconDesiredMonitoringKey];
    if (![CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]]){
        [self emitStatusMessage:@"当前设备不支持 iBeacon region monitoring。"];
        return;
    }
    
    CLAuthorizationStatus status = [self currentAuthorizationStatus];
    if (status == kCLAuthorizationStatusNotDetermined) {
          [self.locationManager requestAlwaysAuthorization];
          [self emitStatusMessage:@"尚未授权，已请求 Always Location 权限。"];
          return;
      }

      if (status != kCLAuthorizationStatusAuthorizedAlways) {
          [self emitStatusMessage:@"需要 Always Location 权限才能在后台监听 iBeacon。"];
          return;
      }
    
    if(![self isMonitoring]){
        [self.locationManager startMonitoringForRegion:self.beaconRegion];
    }
    
    [self.locationManager requestStateForRegion:self.beaconRegion];
    [self emitStatusMessage:[NSString stringWithFormat:@"开始监听 %@", [self currentRegionDescription]]];
}

- (void)stopMonitoring{
    self.desiredMonitoring = NO;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kIBeaconDesiredMonitoringKey];
    CLRegion *region =  [self monitoredRegionWithIdentifier:kIBeaconRegionIdentifier];
    if (region) {
        [self.locationManager stopMonitoringForRegion:region];
    }
    [self emitStatusMessage:@"已停止 iBeacon 监听。"];
}

- (BOOL)isMonitoring{
    return [self monitoredRegionWithIdentifier:kIBeaconRegionIdentifier] != nil;
}

- (NSString *)currentRegionDescription {
    return [NSString stringWithFormat:@"UUID=%@ major=%hu minor=%hu", kIBeaconUUIDString, kIBeaconMajor, kIBeaconMinor];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager{
    CLAuthorizationStatus status = [self currentAuthorizationStatus];
    [self notifyAuthorizationStatus:status];
    
    if (status == kCLAuthorizationStatusAuthorizedAlways){
        [self emitStatusMessage:@"已获得 Always Location 权限。"];
        if(self.desiredMonitoring){
            [self startMonitoring];
        }
        return;
    }
    
    if (status == kCLAuthorizationStatusDenied){
        [self emitStatusMessage:@"定位权限被拒绝，无法监听 iBeacon。"];
        return;
    }
    
    if (status == kCLAuthorizationStatusRestricted) {
        [self emitStatusMessage:@"定位权限受限，无法监听 iBeacon。"];
    }
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region{
    if(![region.identifier isEqualToString:kIBeaconRegionIdentifier]){
        return;
    }
    
    [self emitStatusMessage:@"已进入目标 iBeacon 区域。"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(iBeaconServiceDidEnterRegion:)]) {
            [self.delegate iBeaconServiceDidEnterRegion:self];
        }
    });
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region{
    if(![region.identifier isEqualToString:kIBeaconRegionIdentifier]){
        return;
    }
    [self emitStatusMessage:@"已离开目标 iBeacon 区域。"];
    dispatch_async(dispatch_get_main_queue(), ^{
          if ([self.delegate respondsToSelector:@selector(iBeaconServiceDidExitRegion:)]) {
              [self.delegate iBeaconServiceDidExitRegion:self];
          }
      });
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region{
    if (![region.identifier isEqualToString:kIBeaconRegionIdentifier]) {
        return;
    }
    NSString *message = @"当前区域状态未知。";
    if (state == CLRegionStateInside) {
        message = @"当前已在目标 iBeacon 区域内。";
    } else if (state == CLRegionStateOutside) {
        message = @"当前在目标 iBeacon 区域外。";
    }
    [self emitStatusMessage:message];

    dispatch_async(dispatch_get_main_queue(), ^{
           if ([self.delegate respondsToSelector:@selector(iBeaconService:didDetermineState:)]) {
               [self.delegate iBeaconService:self didDetermineState:state];
           }
       });
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(nullable CLRegion *)region withError:(NSError *)error {
    [self emitStatusMessage:[NSString stringWithFormat:@"region 监听失败: %@", error.localizedDescription]];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [self emitStatusMessage:[NSString stringWithFormat:@"定位服务失败: %@", error.localizedDescription]];
}


- (void)ensureLocationManager {
    if (self.locationManager) {
        return;
    }
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.pausesLocationUpdatesAutomatically = YES;
}

- (CLBeaconRegion *)beaconRegion{
    if(!_beaconRegion){
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:kIBeaconUUIDString];
        _beaconRegion = [[CLBeaconRegion alloc] initWithUUID:uuid
                                         major:kIBeaconMajor
                                         minor:kIBeaconMinor
                                    identifier:kIBeaconRegionIdentifier];
        _beaconRegion.notifyOnEntry = YES;
        _beaconRegion.notifyOnExit = YES;
        _beaconRegion.notifyEntryStateOnDisplay = YES;
    }
    
    return _beaconRegion;
}

- (void)emitStatusMessage:(NSString *)message{
    self.lastStatusMessage = message;
    NSLog(@"[IBeaconService] %@", message);
    dispatch_async(dispatch_get_main_queue(), ^{
        if([self.delegate respondsToSelector:@selector(iBeaconService:didUpdateStatusMessage:)]){
            [self.delegate iBeaconService:self didUpdateStatusMessage:message];
        }
    });
}

- (CLAuthorizationStatus)currentAuthorizationStatus{
    return self.locationManager.authorizationStatus;
}

- (nullable CLRegion *)monitoredRegionWithIdentifier:(NSString *)identifier{
    for (CLRegion *region in self.locationManager.monitoredRegions){
        if([region.identifier isEqualToString:identifier]){
            return region;
        }
    }
    return nil;
}

- (void)notifyAuthorizationStatus:(CLAuthorizationStatus)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(iBeaconService:didChangeAuthorizationStatus:)]) {
            [self.delegate iBeaconService:self didChangeAuthorizationStatus:status];
        }
    });
}

@end
