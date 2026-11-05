//
//  BluetoothAudioMockSession.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const BluetoothMockAudioServiceUUID;
FOUNDATION_EXPORT NSString * const BluetoothMockAudioWriteCharacteristicUUID;
FOUNDATION_EXPORT NSString * const BluetoothMockAudioNotifyCharacteristicUUID;

typedef void (^BluetoothMockStatusHandler)(NSString *message);
typedef void (^BluetoothMockDeviceHandler)(NSDictionary<NSString *, NSString *> *deviceInfo);
typedef void (^BluetoothMockConnectionHandler)(NSString *name, NSUUID *identifier);
typedef void (^BluetoothMockDisconnectionHandler)(NSString *name, NSUUID *identifier, NSError * _Nullable error);
typedef void (^BluetoothMockValueHandler)(NSData *data, NSString *characteristicUUID);
typedef void (^BluetoothMockAudioHandler)(NSData *audioFrame, NSDictionary<NSString *, id> *metadata);
typedef void (^BluetoothMockMetricsHandler)(NSDictionary<NSString *, id> *metrics);

@interface BluetoothAudioMockSession : NSObject

@property (nonatomic, copy, nullable) BluetoothMockStatusHandler statusHandler;
@property (nonatomic, copy, nullable) BluetoothMockDeviceHandler deviceHandler;
@property (nonatomic, copy, nullable) BluetoothMockConnectionHandler connectionHandler;
@property (nonatomic, copy, nullable) BluetoothMockDisconnectionHandler disconnectionHandler;
@property (nonatomic, copy, nullable) BluetoothMockValueHandler valueHandler;
@property (nonatomic, copy, nullable) BluetoothMockAudioHandler audioHandler;
@property (nonatomic, copy, nullable) BluetoothMockMetricsHandler metricsHandler;

@property (nonatomic, strong, readonly) NSUUID *mockIdentifier;
@property (nonatomic, assign, readonly, getter=isScanning) BOOL scanning;
@property (nonatomic, assign, readonly, getter=isConnected) BOOL connected;
@property (nonatomic, assign, readonly, getter=isStreaming) BOOL streaming;
@property (nonatomic, copy, readonly) NSString *connectionDescription;
@property (nonatomic, strong, readonly) NSDictionary<NSString *, id> *currentMetrics;

- (NSArray<NSDictionary<NSString *, NSString *> *> *)discoveredDevices;
- (BOOL)ownsIdentifier:(NSUUID *)identifier;

- (void)startScan;
- (void)stopScan;
- (void)connectPeripheralWithIdentifier:(NSUUID *)identifier;
- (void)disconnect;

- (void)sendCommandData:(NSData *)data;
- (void)startStreaming;
- (void)stopStreaming;

@end

NS_ASSUME_NONNULL_END
