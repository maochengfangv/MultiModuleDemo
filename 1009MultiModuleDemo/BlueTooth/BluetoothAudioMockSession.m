//
//  BluetoothAudioMockSession.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/20.
//

#import "BluetoothAudioMockSession.h"
#import <math.h>

NSString * const BluetoothMockAudioServiceUUID = @"FFF0";
NSString * const BluetoothMockAudioWriteCharacteristicUUID = @"FFF1";
NSString * const BluetoothMockAudioNotifyCharacteristicUUID = @"FFF2";

static NSString * const kMockPeripheralName = @"MockRecorder";
static NSString * const kMockPeripheralUUIDString = @"7D9B2A11-4F5D-4D91-A9A0-14F5CC010001";
static NSTimeInterval const kMockPacketInterval = 0.10;
static NSUInteger const kMockSampleRate = 16000;
static NSUInteger const kMockChannels = 1;
static NSUInteger const kMockBitsPerSample = 16;
static NSUInteger const kMockSamplesPerPacket = 1600;

@interface BluetoothAudioMockSession ()

@property (nonatomic, strong, readwrite) NSUUID *mockIdentifier;
@property (nonatomic, assign, readwrite, getter=isScanning) BOOL scanning;
@property (nonatomic, assign, readwrite, getter=isConnected) BOOL connected;
@property (nonatomic, assign, readwrite, getter=isStreaming) BOOL streaming;
@property (nonatomic, copy, readwrite) NSString *connectionDescription;
@property (nonatomic, strong) dispatch_queue_t audioQueue;
@property (nonatomic, strong) dispatch_source_t audioTimer;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *mockDeviceInfo;
@property (nonatomic, assign) NSUInteger packetIndex;
@property (nonatomic, assign) NSUInteger totalBytes;
@property (nonatomic, strong, nullable) NSDate *streamStartedAt;

@end

@implementation BluetoothAudioMockSession

- (instancetype)init {
    self = [super init];
    if (self) {
        _mockIdentifier = [[NSUUID alloc] initWithUUIDString:kMockPeripheralUUIDString];
        _connectionDescription = @"当前无蓝牙连接";
        _audioQueue = dispatch_queue_create("com.maocf.demo.bluetooth.mock.audio", DISPATCH_QUEUE_SERIAL);
        _mockDeviceInfo = @{
            @"identifier" : _mockIdentifier.UUIDString ?: @"",
            @"name" : kMockPeripheralName,
            @"rssi" : @"-42",
            @"isConnectable" : @"YES",
            @"serviceUUID" : BluetoothMockAudioServiceUUID,
            @"transport" : @"MOCK_AUDIO"
        };
    }
    return self;
}

- (NSArray<NSDictionary<NSString *,NSString *> *> *)discoveredDevices {
    return @[self.mockDeviceInfo ?: @{}];
}

- (BOOL)ownsIdentifier:(NSUUID *)identifier {
    return [identifier.UUIDString isEqualToString:self.mockIdentifier.UUIDString];
}

- (void)startScan {
    self.scanning = YES;
    if (self.deviceHandler) {
        self.deviceHandler(self.mockDeviceInfo);
    }
    if (self.statusHandler) {
        self.statusHandler(@"Mock 录音设备已发布，支持 AA5501 开始流、AA5502 停止流。");
    }
}

- (void)stopScan {
    self.scanning = NO;
    if (self.statusHandler) {
        self.statusHandler(@"Mock 录音设备扫描已停止。");
    }
}

- (void)connectPeripheralWithIdentifier:(NSUUID *)identifier {
    if (![self ownsIdentifier:identifier]) {
        if (self.statusHandler) {
            self.statusHandler(@"Mock 连接失败，目标设备不匹配。");
        }
        return;
    }
    self.connected = YES;
    self.connectionDescription = [NSString stringWithFormat:@"设备=%@ 状态=Connected(Mock)", kMockPeripheralName];
    if (self.statusHandler) {
        self.statusHandler(@"Mock 录音设备连接成功，通知特征已就绪。");
    }
    if (self.connectionHandler) {
        self.connectionHandler(kMockPeripheralName, self.mockIdentifier);
    }
}

- (void)disconnect {
    if (!self.connected) {
        return;
    }
    [self stopStreaming];
    self.connected = NO;
    self.connectionDescription = @"当前无蓝牙连接";
    if (self.statusHandler) {
        self.statusHandler(@"Mock 录音设备已断开。");
    }
    if (self.disconnectionHandler) {
        self.disconnectionHandler(kMockPeripheralName, self.mockIdentifier, nil);
    }
}

- (void)sendCommandData:(NSData *)data {
    if (!self.connected) {
        if (self.statusHandler) {
            self.statusHandler(@"Mock 指令拒绝，当前未连接录音设备。");
        }
        return;
    }

    const unsigned char *bytes = data.bytes;
    if (data.length == 3 && bytes[0] == 0xAA && bytes[1] == 0x55 && bytes[2] == 0x01) {
        [self startStreaming];
        return;
    }
    if (data.length == 3 && bytes[0] == 0xAA && bytes[1] == 0x55 && bytes[2] == 0x02) {
        [self stopStreaming];
        return;
    }

    NSMutableData *ack = [NSMutableData data];
    uint8_t header[] = {0xAC, 0x4B, (uint8_t)MIN(data.length, 255)};
    [ack appendBytes:header length:sizeof(header)];
    [ack appendData:data];
    if (self.valueHandler) {
        self.valueHandler(ack.copy, BluetoothMockAudioNotifyCharacteristicUUID);
    }
    if (self.statusHandler) {
        self.statusHandler([NSString stringWithFormat:@"Mock 已回传 ACK，长度=%lu", (unsigned long)ack.length]);
    }
}

- (void)startStreaming {
    if (!self.connected) {
        if (self.statusHandler) {
            self.statusHandler(@"Mock 音频流启动失败，设备尚未连接。");
        }
        return;
    }
    if (self.streaming) {
        return;
    }

    self.streaming = YES;
    self.packetIndex = 0;
    self.totalBytes = 0;
    self.streamStartedAt = [NSDate date];

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.audioQueue);
    self.audioTimer = timer;

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, 0),
                              (uint64_t)(kMockPacketInterval * NSEC_PER_SEC),
                              (uint64_t)(0.01 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(timer, ^{
        [weakSelf emitAudioPacket];
    });
    dispatch_resume(timer);

    if (self.statusHandler) {
        self.statusHandler(@"Mock 音频流已启动，输出 16kHz PCM 分片。");
    }
    if (self.metricsHandler) {
        self.metricsHandler(self.currentMetrics);
    }
}

- (void)stopStreaming {
    if (!self.streaming) {
        return;
    }
    self.streaming = NO;

    if (self.audioTimer) {
        dispatch_source_cancel(self.audioTimer);
        self.audioTimer = nil;
    }

    if (self.statusHandler) {
        self.statusHandler(@"Mock 音频流已停止。");
    }
    if (self.metricsHandler) {
        self.metricsHandler(self.currentMetrics);
    }
}

- (NSDictionary<NSString *,id> *)currentMetrics {
    NSTimeInterval duration = self.streamStartedAt ? [[NSDate date] timeIntervalSinceDate:self.streamStartedAt] : 0;
    return @{
        @"source" : @"mock_recording_device",
        @"codec" : @"pcm_s16le",
        @"sampleRate" : @(kMockSampleRate),
        @"channels" : @(kMockChannels),
        @"bitsPerSample" : @(kMockBitsPerSample),
        @"packetCount" : @(self.packetIndex),
        @"totalBytes" : @(self.totalBytes),
        @"durationMs" : @((NSUInteger)lrint(duration * 1000.0))
    };
}

- (void)emitAudioPacket {
    if (!self.streaming) {
        return;
    }

    NSMutableData *payload = [NSMutableData dataWithCapacity:kMockSamplesPerPacket * 2];
    double frequency = 440.0;

    for (NSUInteger index = 0; index < kMockSamplesPerPacket; index++) {
        double sampleCursor = (double)(self.packetIndex * kMockSamplesPerPacket + index) / (double)kMockSampleRate;
        double amplitude = sin(2.0 * M_PI * frequency * sampleCursor) * 0.55;
        int16_t pcm = (int16_t)lrint(amplitude * 32767.0);
        [payload appendBytes:&pcm length:sizeof(int16_t)];
    }

    self.packetIndex += 1;
    self.totalBytes += payload.length;

    NSDictionary<NSString *, id> *metadata = @{
        @"source" : @"mock_recording_device",
        @"codec" : @"pcm_s16le",
        @"sampleRate" : @(kMockSampleRate),
        @"channels" : @(kMockChannels),
        @"bitsPerSample" : @(kMockBitsPerSample),
        @"packetIndex" : @(self.packetIndex),
        @"timestampMs" : @((NSUInteger)lrint([[NSDate date] timeIntervalSince1970] * 1000.0))
    };

    if (self.valueHandler) {
        self.valueHandler(payload.copy, BluetoothMockAudioNotifyCharacteristicUUID);
    }
    if (self.audioHandler) {
        self.audioHandler(payload.copy, metadata);
    }
    if (self.metricsHandler && self.packetIndex % 10 == 0) {
        self.metricsHandler(self.currentMetrics);
    }
}

@end
