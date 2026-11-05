//
//  IBeaconService.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/9.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol IBeaconService;

@protocol IBeaconServiceDelegate <NSObject>
@optional
- (void)iBeaconService:(id<IBeaconService>)service didUpdateStatusMessage:(NSString *)message;
- (void)iBeaconService:(id<IBeaconService>)service didChangeAuthorizationStatus:(CLAuthorizationStatus)status;
- (void)iBeaconServiceDidEnterRegion:(id<IBeaconService>)service;
- (void)iBeaconServiceDidExitRegion:(id<IBeaconService>)service;
- (void)iBeaconService:(id<IBeaconService>)service didDetermineState:(CLRegionState)state;
@end

@protocol IBeaconService <NSObject>

@property (nonatomic, weak, nullable) id<IBeaconServiceDelegate> delegate;

- (void)bootstrapWithLaunchOptions:(nullable NSDictionary *)launchOptions;
- (void)requestAlwaysAuthorization;
- (void)startMonitoring;
- (void)stopMonitoring;
- (BOOL)isMonitoring;
- (NSString *)currentRegionDescription;

@end

NS_ASSUME_NONNULL_END
