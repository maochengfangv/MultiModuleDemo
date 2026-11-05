//
//  BluetoothServiceImpl.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/10.
//

#import "BluetoothServiceImpl.h"
#import "Router.h"
#import "BluetoothAudioMockSession.h"
#import <CoreBluetooth/CoreBluetooth.h>

static NSString * const kBluetoothRestoreIdentifier = @"com.maocf.demo.bluetooth.central.restore";

@interface BluetoothServiceImpl ()<CBCentralManagerDelegate,CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableDictionary<NSUUID *, CBPeripheral *> *discoveredPeripheralMap;
@property (nonatomic, strong) NSMutableDictionary<NSUUID *, NSDictionary<NSString *, NSString *> *> *deviceInfoMap;
@property (nonatomic, strong, nullable) CBPeripheral *currentPeripheral;
@property (nonatomic, strong, nullable) CBCharacteristic *writeCharacteristic;
@property (nonatomic, strong, nullable) CBCharacteristic *notifyCharacteristic;
@property (nonatomic, copy, nullable) NSString *preferredServiceUUIDString;
@property (nonatomic, copy, nullable) NSString *preferredWriteCharacteristicUUIDString;
@property (nonatomic, copy, nullable) NSString *preferredNotifyCharacteristicUUIDString;
@property (nonatomic, strong) BluetoothAudioMockSession *mockSession;

- (instancetype)initSingleton;
- (void)bindMockSessionCallbacks;

@end

@implementation BluetoothServiceImpl

+ (void)load{
    [[Router shared] registerProtocol:@protocol(BluetoothService) impl:[self class]];
}

+ (instancetype)sharedInstance{
    static BluetoothServiceImpl *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] initSingleton];
    });
    return instance;
}

- (instancetype)initSingleton {
    self = [super init];
    if (self) {
        _discoveredPeripheralMap = [NSMutableDictionary dictionary];
        _deviceInfoMap = [NSMutableDictionary dictionary];
        _mockSession = [[BluetoothAudioMockSession alloc] init];
        [self bindMockSessionCallbacks];
    }
    return self;
}

- (void)bootstrapWithLaunchOptions:(NSDictionary *)launchOptions {
    [self ensureCentralManager];
    if (launchOptions.count > 0) {
        [self emitStatusMessage:@"蓝牙模块已完成启动初始化。"];
    }
}

- (void)configurePreferredServiceUUIDString:(NSString *)serviceUUIDString
              writeCharacteristicUUIDString:(NSString *)writeCharacteristicUUIDString
             notifyCharacteristicUUIDString:(NSString *)notifyCharacteristicUUIDString {
    self.preferredServiceUUIDString = serviceUUIDString.length > 0 ? serviceUUIDString.uppercaseString : nil;
    self.preferredWriteCharacteristicUUIDString = writeCharacteristicUUIDString.length > 0 ? writeCharacteristicUUIDString.uppercaseString : nil;
    self.preferredNotifyCharacteristicUUIDString = notifyCharacteristicUUIDString.length > 0 ? notifyCharacteristicUUIDString.uppercaseString : nil;
}

- (void)startScan {
    [self ensureCentralManager];
    [self.deviceInfoMap removeAllObjects];
    [self.discoveredPeripheralMap removeAllObjects];
    [self.mockSession startScan];
    if (self.centralManager.state != CBManagerStatePoweredOn) {
        [self emitStatusMessage:[NSString stringWithFormat:@"蓝牙硬件不可用，已切换 Mock 录音设备模式: %@", [self stringFromManagerState:self.centralManager.state]]];
        return;
    }
    NSArray<CBUUID *> *serviceUUIDs = nil;
    if (self.preferredServiceUUIDString.length > 0) {
        serviceUUIDs = @[[CBUUID UUIDWithString:self.preferredServiceUUIDString]];
    }
    [self.centralManager scanForPeripheralsWithServices:serviceUUIDs options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @NO}];
    [self emitStatusMessage:@"开始扫描附近蓝牙设备。"];
}

- (void)stopScan {
    [self.mockSession stopScan];
    [self.centralManager stopScan];
    [self emitStatusMessage:@"已停止蓝牙扫描。"];
}

- (BOOL)isScanning{
    return self.centralManager.isScanning || self.mockSession.isScanning;
}

- (NSArray<NSDictionary<NSString *,NSString *> *> *)discoveredDevices {
    return  self.deviceInfoMap.allValues;
}

- (void)connectPeripheralWithIdentifier:(NSUUID *)identifier {
    if ([self.mockSession ownsIdentifier:identifier]) {
        [self.mockSession connectPeripheralWithIdentifier:identifier];
        return;
    }

    [self ensureCentralManager];
    if (self.centralManager.state != CBManagerStatePoweredOn) {
        [self emitStatusMessage:@"蓝牙未开启，无法连接设备。"]; 
        return;
    }

    CBPeripheral *peripheral = self.discoveredPeripheralMap[identifier];
    if (!peripheral) {
        NSArray<CBPeripheral *> *retrieved = [self.centralManager retrievePeripheralsWithIdentifiers:@[identifier]];
        peripheral = retrieved.firstObject;
    }
    
    if (!peripheral) {
        [self emitStatusMessage:[NSString stringWithFormat:@"未找到目标设备: %@", identifier.UUIDString]];
        return;
    }
    
    self.currentPeripheral = peripheral;
    self.writeCharacteristic = nil;
    self.notifyCharacteristic = nil;
    [self.centralManager stopScan];
    [self.centralManager connectPeripheral:peripheral
                                   options:@{
        CBConnectPeripheralOptionNotifyOnConnectionKey : @YES,
        CBConnectPeripheralOptionNotifyOnDisconnectionKey : @YES,
        CBConnectPeripheralOptionNotifyOnNotificationKey : @YES
    }];
    [self emitStatusMessage:[NSString stringWithFormat:@"正在连接设备: %@", [self peripheralDisplayName:peripheral]]];
}

- (void)disconnectCurrentPeripheral {
    if ([self.mockSession isConnected]) {
        [self.mockSession disconnect];
        return;
    }
    if (!self.currentPeripheral) {
        [self emitStatusMessage:@"当前没有已连接的蓝牙设备。"]; 
        return;
    }
    [self.centralManager cancelPeripheralConnection:self.currentPeripheral];
}

- (BOOL)isConnected {
    return self.currentPeripheral.state == CBPeripheralStateConnected || [self.mockSession isConnected];
}

- (NSString *)currentConnectionDescription {
    if ([self.mockSession isConnected]) {
        return self.mockSession.connectionDescription;
    }
    if (!self.currentPeripheral) {
        return @"当前无蓝牙连接";
    }
    return [NSString stringWithFormat:@"设备=%@ 状态=%@",
            [self peripheralDisplayName:self.currentPeripheral],
            [self stringFromPeripheralState:self.currentPeripheral.state]];
}

- (void)sendCommandData:(NSData *)data{
    if (data.length == 0) {
        [self emitStatusMessage:@"发送失败，指令数据为空。"];
        return;
    }
    
    if ([self.mockSession isConnected]) {
        [self.mockSession sendCommandData:data];
        return;
    }

    if (!self.currentPeripheral || self.currentPeripheral.state != CBPeripheralStateConnected) {
        [self emitStatusMessage:@"发送失败，当前没有已连接设备。"]; 
        return;
    }
    
    if (!self.writeCharacteristic) {
        [self emitStatusMessage:@"发送失败，尚未发现可写特征。"];
        return;
    }
    
    CBCharacteristicWriteType writeType = CBCharacteristicWriteWithResponse;
    if (self.writeCharacteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) {
        writeType = CBCharacteristicWriteWithoutResponse;
    }
    
    [self.currentPeripheral writeValue:data forCharacteristic:self.writeCharacteristic type:writeType];
    [self emitStatusMessage:[NSString stringWithFormat:@"已发送蓝牙指令，长度=%lu", (unsigned long)data.length]];
}

- (void)sendHexCommand:(NSString *)hexCommand{
    NSData *data = [self dataFromHexString:hexCommand];
    if (!data) {
        [self emitStatusMessage:@"发送失败，HEX 指令格式非法。"]; 
        return;
    }
    [self sendCommandData:data];
}

- (void)startMockAudioStreaming {
    [self.mockSession startStreaming];
}

- (void)stopMockAudioStreaming {
    [self.mockSession stopStreaming];
}

- (BOOL)isStreamingAudio {
    return self.mockSession.isStreaming;
}

- (NSDictionary<NSString *,id> *)currentAudioStreamMetrics {
    return self.mockSession.currentMetrics;
}

- (void)bindMockSessionCallbacks {
    __weak typeof(self) weakSelf = self;
    self.mockSession.statusHandler = ^(NSString *message) { [weakSelf emitStatusMessage:message]; };
    self.mockSession.deviceHandler = ^(NSDictionary<NSString *,NSString *> *deviceInfo) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        self.deviceInfoMap[self.mockSession.mockIdentifier] = deviceInfo;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(bluetoothService:didDiscoverDeviceInfo:)]) {
                [self.delegate bluetoothService:self didDiscoverDeviceInfo:deviceInfo];
            }
        });
    };
    self.mockSession.connectionHandler = ^(NSString *name, NSUUID *identifier) {
        __strong typeof(weakSelf) self = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(bluetoothService:didConnectPeripheralNamed:identifier:)]) {
                [self.delegate bluetoothService:self didConnectPeripheralNamed:name identifier:identifier];
            }
        });
    };
    self.mockSession.disconnectionHandler = ^(NSString *name, NSUUID *identifier, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(bluetoothService:didDisconnectPeripheralNamed:identifier:error:)]) {
                [self.delegate bluetoothService:self didDisconnectPeripheralNamed:name identifier:identifier error:error];
            }
        });
    };
    self.mockSession.valueHandler = ^(NSData *data, NSString *uuid) {
        __strong typeof(weakSelf) self = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(bluetoothService:didReceiveValue:characteristicUUID:)]) {
                [self.delegate bluetoothService:self didReceiveValue:data characteristicUUID:uuid];
            }
        });
    };
    self.mockSession.audioHandler = ^(NSData *frame, NSDictionary<NSString *,id> *metadata) {
        __strong typeof(weakSelf) self = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(bluetoothService:didReceiveAudioFrame:metadata:)]) {
                [self.delegate bluetoothService:self didReceiveAudioFrame:frame metadata:metadata];
            }
        });
    };
    self.mockSession.metricsHandler = ^(NSDictionary<NSString *,id> *metrics) {
        __strong typeof(weakSelf) self = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(bluetoothService:didUpdateAudioStreamMetrics:)]) {
                [self.delegate bluetoothService:self didUpdateAudioStreamMetrics:metrics];
            }
        });
    };
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    [self emitStatusMessage:[NSString stringWithFormat:@"蓝牙状态变更: %@", [self stringFromManagerState:central.state]]];
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *,id> *)dict{
    NSArray<CBPeripheral *> *restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey];
       CBPeripheral *peripheral = restoredPeripherals.firstObject;
    if (!peripheral) {
        [self emitStatusMessage:@"蓝牙状态恢复完成，但没有可恢复设备。"];
        return;
    }
    self.currentPeripheral = peripheral;
    self.currentPeripheral.delegate = self;
    [self emitStatusMessage:[NSString stringWithFormat:@"已恢复蓝牙设备: %@", [self peripheralDisplayName:peripheral]]];

    if (peripheral.state == CBPeripheralStateConnected) {
        [peripheral discoverServices:[self preferredServiceUUIDObjects]];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    self.discoveredPeripheralMap[peripheral.identifier] = peripheral;

        NSString *name = [self peripheralDisplayName:peripheral];
        NSDictionary<NSString *, NSString *> *info = @{
            @"identifier" : peripheral.identifier.UUIDString ?: @"",
            @"name" : name,
            @"rssi" : RSSI.stringValue ?: @"",
            @"isConnectable" : [advertisementData[CBAdvertisementDataIsConnectable] boolValue] ? @"YES" : @"NO"
        };
        self.deviceInfoMap[peripheral.identifier] = info;

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(bluetoothService:didDiscoverDeviceInfo:)]) {
                [self.delegate bluetoothService:self didDiscoverDeviceInfo:info];
            }
        });
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    self.currentPeripheral = peripheral;
    self.currentPeripheral.delegate = self;
    self.writeCharacteristic = nil;
    self.notifyCharacteristic = nil;

    [self emitStatusMessage:[NSString stringWithFormat:@"蓝牙连接成功: %@", [self peripheralDisplayName:peripheral]]];

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(bluetoothService:didConnectPeripheralNamed:identifier:)]) {
            [self.delegate bluetoothService:self
                   didConnectPeripheralNamed:[self peripheralDisplayName:peripheral]
                                  identifier:peripheral.identifier];
        }
    });

    [peripheral discoverServices:[self preferredServiceUUIDObjects]];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self emitStatusMessage:[NSString stringWithFormat:@"蓝牙连接失败: %@", error.localizedDescription ?: @"未知错误"]];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    NSString *name = [self peripheralDisplayName:peripheral];
    [self emitStatusMessage:[NSString stringWithFormat:@"蓝牙已断开: %@", name]];

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(bluetoothService:didDisconnectPeripheralNamed:identifier:error:)]) {
            [self.delegate bluetoothService:self
                didDisconnectPeripheralNamed:name
                                  identifier:peripheral.identifier
                                       error:error];
        }
    });

    if ([self.currentPeripheral.identifier isEqual:peripheral.identifier]) {
        self.currentPeripheral = nil;
        self.writeCharacteristic = nil;
        self.notifyCharacteristic = nil;
    }
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if(error){
        [self emitStatusMessage:[NSString stringWithFormat:@"发现服务失败: %@", error.localizedDescription]];
        return;
    }
    
    for (CBService * serivce in peripheral.services) {
        NSArray<CBUUID *> *characteristicUUIDs = [self preferredCharacteristicUUIDObjects];
        [peripheral discoverCharacteristics:characteristicUUIDs forService:serivce];
    }
    [self emitStatusMessage:@"已发现蓝牙服务，开始发现特征。"];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    if (error) {
        [self emitStatusMessage:[NSString stringWithFormat:@"发现特征失败: %@", error.localizedDescription]];
        return;
    }
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSString *uuid = characteristic.UUID.UUIDString.uppercaseString;

        if ([self isPreferredNotifyCharacteristic:uuid] &&
            (characteristic.properties & CBCharacteristicPropertyNotify)) {
            self.notifyCharacteristic = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }

        if ([self isPreferredWriteCharacteristic:uuid] &&
            [self isWritableCharacteristic:characteristic]) {
            self.writeCharacteristic = characteristic;
        }
    }

    if (!self.writeCharacteristic) {
        for (CBCharacteristic *characteristic in service.characteristics) {
            if ([self isWritableCharacteristic:characteristic]) {
                self.writeCharacteristic = characteristic;
                break;
            }
        }
    }

    if (!self.notifyCharacteristic) {
        for (CBCharacteristic *characteristic in service.characteristics) {
            if (characteristic.properties & CBCharacteristicPropertyNotify) {
                self.notifyCharacteristic = characteristic;
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                break;
            }
        }
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (self.writeCharacteristic) {
        [parts addObject:[NSString stringWithFormat:@"write=%@", self.writeCharacteristic.UUID.UUIDString]];
    }
    if (self.notifyCharacteristic) {
        [parts addObject:[NSString stringWithFormat:@"notify=%@", self.notifyCharacteristic.UUID.UUIDString]];
    }

    if (parts.count == 0) {
        [self emitStatusMessage:@"连接成功，但未找到可写/可通知特征。"];
    } else {
        [self emitStatusMessage:[NSString stringWithFormat:@"特征准备完成: %@", [parts componentsJoinedByString:@" "]]];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        [self emitStatusMessage:[NSString stringWithFormat:@"接收蓝牙数据失败: %@", error.localizedDescription]];
        return;
    }

    NSData *value = characteristic.value ?: [NSData data];
    NSString *uuid = characteristic.UUID.UUIDString.uppercaseString;

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(bluetoothService:didReceiveValue:characteristicUUID:)]) {
            [self.delegate bluetoothService:self didReceiveValue:value characteristicUUID:uuid];
        }
    });

    [self emitStatusMessage:[NSString stringWithFormat:@"收到蓝牙数据，特征=%@ 长度=%lu", uuid, (unsigned long)value.length]];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        [self emitStatusMessage:[NSString stringWithFormat:@"蓝牙指令发送失败: %@", error.localizedDescription]];
        return;
    }

    [self emitStatusMessage:[NSString stringWithFormat:@"蓝牙指令发送成功: %@", characteristic.UUID.UUIDString]];
}

#pragma mark - Private

- (void)ensureCentralManager {
    if (self.centralManager) {
        return;
    }
    
    NSDictionary *options = @{
        CBCentralManagerOptionShowPowerAlertKey: @YES,
        CBCentralManagerOptionRestoreIdentifierKey: kBluetoothRestoreIdentifier,
    };
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:options];
}

- (void)emitStatusMessage:(NSString *)message {
    NSLog(@"[BluetoothService] %@", message);

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(bluetoothService:didUpdateStatusMessage:)]) {
            [self.delegate bluetoothService:self didUpdateStatusMessage:message];
        }
    });
}

- (NSString *)stringFromManagerState:(CBManagerState)state {
    switch (state) {
        case CBManagerStateUnknown:
            return @"Unknown";
        case CBManagerStateResetting:
            return @"Resetting";
        case CBManagerStateUnsupported:
            return @"Unsupported";
        case CBManagerStateUnauthorized:
            return @"Unauthorized";
        case CBManagerStatePoweredOff:
            return @"PoweredOff";
        case CBManagerStatePoweredOn:
            return @"PoweredOn";
    }
}

- (NSString *)stringFromPeripheralState:(CBPeripheralState)state {
    switch (state) {
        case CBPeripheralStateDisconnected:
            return @"Disconnected";
        case CBPeripheralStateConnecting:
            return @"Connecting";
        case CBPeripheralStateConnected:
            return @"Connected";
        case CBPeripheralStateDisconnecting:
            return @"Disconnecting";
    }
}

- (NSString *)peripheralDisplayName:(CBPeripheral *)peripheral {
    if (peripheral.name.length > 0) {
        return peripheral.name;
    }

    NSDictionary<NSString *, NSString *> *info = self.deviceInfoMap[peripheral.identifier];
    if (info[@"name"].length > 0) {
        return info[@"name"];
    }

    return @"未命名设备";
}

- (NSArray<CBUUID *> * _Nullable)preferredServiceUUIDObjects {
    if (self.preferredServiceUUIDString.length == 0) {
        return nil;
    }
    return @[[CBUUID UUIDWithString:self.preferredServiceUUIDString]];
}

- (BOOL)isPreferredNotifyCharacteristic:(NSString *)uuidString {
    if (self.preferredNotifyCharacteristicUUIDString.length == 0) {
        return YES;
    }
    return [uuidString isEqualToString:self.preferredNotifyCharacteristicUUIDString];
}

- (BOOL)isPreferredWriteCharacteristic:(NSString *)uuidString {
    if (self.preferredWriteCharacteristicUUIDString.length == 0) {
        return YES;
    }
    return [uuidString isEqualToString:self.preferredWriteCharacteristicUUIDString];
}

- (BOOL)isWritableCharacteristic:(CBCharacteristic *)characteristic {
    return (characteristic.properties & CBCharacteristicPropertyWrite) ||
           (characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse);
}

- (NSData * _Nullable)dataFromHexString:(NSString *)hexString {
    NSString *normalized = [[hexString stringByReplacingOccurrencesOfString:@" " withString:@""]
                            stringByReplacingOccurrencesOfString:@"<" withString:@""];
    normalized = [[normalized stringByReplacingOccurrencesOfString:@">" withString:@""]
                  stringByReplacingOccurrencesOfString:@"0x" withString:@""];
    normalized = normalized.uppercaseString;

    if (normalized.length == 0 || normalized.length % 2 != 0) {
        return nil;
    }

    NSMutableData *data = [NSMutableData dataWithCapacity:normalized.length / 2];
    for (NSUInteger index = 0; index < normalized.length; index += 2) {
        NSString *byteString = [normalized substringWithRange:NSMakeRange(index, 2)];
        unsigned int value = 0;
        NSScanner *scanner = [NSScanner scannerWithString:byteString];
        if (![scanner scanHexInt:&value]) {
            return nil;
        }

        uint8_t byte = (uint8_t)value;
        [data appendBytes:&byte length:1];
    }

    return data.copy;
}

- (NSArray<CBUUID *> * _Nullable)preferredCharacteristicUUIDObjects {
    NSMutableArray<CBUUID *> *result = [NSMutableArray array];

    if (self.preferredWriteCharacteristicUUIDString.length > 0) {
        [result addObject:[CBUUID UUIDWithString:self.preferredWriteCharacteristicUUIDString]];
    }

    if (self.preferredNotifyCharacteristicUUIDString.length > 0 &&
        ![self.preferredNotifyCharacteristicUUIDString isEqualToString:self.preferredWriteCharacteristicUUIDString]) {
        [result addObject:[CBUUID UUIDWithString:self.preferredNotifyCharacteristicUUIDString]];
    }

    return result.count > 0 ? result.copy : nil;
}



@end
