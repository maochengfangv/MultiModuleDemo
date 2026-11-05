//
//  BluetoothServiceImpl.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/10.
//

#import <Foundation/Foundation.h>
#import "BluetoothService.h"
#import "SharedServiceProvider.h"
NS_ASSUME_NONNULL_BEGIN

@interface BluetoothServiceImpl : NSObject<BluetoothService, SharedServiceProvider>

@property (nonatomic, weak, nullable) id<BluetoothServiceDelegate> delegate;

+ (instancetype)sharedInstance;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
