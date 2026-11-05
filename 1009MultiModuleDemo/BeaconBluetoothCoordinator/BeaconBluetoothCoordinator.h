//
//  BeaconBluetoothCoordinator.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const BeaconBluetoothCoordinatorStateDidChangeNotification;
FOUNDATION_EXPORT NSString * const BeaconBluetoothCoordinatorBeaconStatusKey;
FOUNDATION_EXPORT NSString * const BeaconBluetoothCoordinatorBluetoothStatusKey;
FOUNDATION_EXPORT NSString * const BeaconBluetoothCoordinatorDevicesKey;
FOUNDATION_EXPORT NSString * const BeaconBluetoothCoordinatorAudioStatusKey;

@protocol BeaconBluetoothCoordinator <NSObject>

- (void)bootstrapWithLaunchOptions:(nullable NSDictionary *)launchOptions;
- (void)requestLocationAuthorizationAndStartMonitoring;

- (void)toggleManualScan;
- (void)connectDeviceWithIdentifier:(NSUUID *)identifier;
- (void)sendHexCommand:(NSString *)hexCommand;
- (void)toggleMockAudioStreaming;

- (BOOL)isScanning;
- (BOOL)isStreamingAudio;
- (NSArray<NSDictionary<NSString *, NSString *> *> *)currentDevices;
- (NSString *)currentBeaconStatus;
- (NSString *)currentBluetoothStatus;
- (NSString *)currentAudioStatus;

@end

NS_ASSUME_NONNULL_END
