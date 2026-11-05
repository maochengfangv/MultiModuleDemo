//
//  BluetoothService.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/10.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BluetoothService;

@protocol BluetoothServiceDelegate <NSObject>
@optional
- (void)bluetoothService:(id<BluetoothService>)service didUpdateStatusMessage:(NSString *)message;
- (void)bluetoothService:(id<BluetoothService>)service didDiscoverDeviceInfo:(NSDictionary<NSString *, NSString *> *)deviceInfo;
- (void)bluetoothService:(id<BluetoothService>)service didConnectPeripheralNamed:(NSString *)name identifier:(NSUUID *)identifier;
- (void)bluetoothService:(id<BluetoothService>)service didDisconnectPeripheralNamed:(NSString *)name
              identifier:(NSUUID *)identifier
                   error:(nullable NSError *)error;
- (void)bluetoothService:(id<BluetoothService>)service
          didReceiveValue:(NSData *)data
      characteristicUUID:(NSString *)characteristicUUID;
- (void)bluetoothService:(id<BluetoothService>)service
    didReceiveAudioFrame:(NSData *)audioFrame
                metadata:(NSDictionary<NSString *, id> *)metadata;
- (void)bluetoothService:(id<BluetoothService>)service
 didUpdateAudioStreamMetrics:(NSDictionary<NSString *, id> *)metrics;
@end

@protocol BluetoothService <NSObject>

@property (nonatomic, weak, nullable) id<BluetoothServiceDelegate> delegate;

- (void)bootstrapWithLaunchOptions:(nullable NSDictionary *)launchOptions;

- (void)configurePreferredServiceUUIDString:(nullable NSString *)serviceUUIDString
             writeCharacteristicUUIDString:(nullable NSString *)writeCharacteristicUUIDString
            notifyCharacteristicUUIDString:(nullable NSString *)notifyCharacteristicUUIDString;

- (void)startScan;
- (void)stopScan;
- (BOOL)isScanning;
- (NSArray<NSDictionary<NSString *, NSString *> *> *)discoveredDevices;

- (void)connectPeripheralWithIdentifier:(NSUUID *)identifier;
- (void)disconnectCurrentPeripheral;
- (BOOL)isConnected;
- (NSString *)currentConnectionDescription;

- (void)sendCommandData:(NSData *)data;
- (void)sendHexCommand:(NSString *)hexCommand;

- (void)startMockAudioStreaming;
- (void)stopMockAudioStreaming;
- (BOOL)isStreamingAudio;
- (NSDictionary<NSString *, id> *)currentAudioStreamMetrics;

@end

NS_ASSUME_NONNULL_END

