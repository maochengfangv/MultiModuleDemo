//
//  BeaconBluetoothCoordinatorImpl.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/10.
//

#import <Foundation/Foundation.h>
#import "BeaconBluetoothCoordinator.h"
#import "SharedServiceProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeaconBluetoothCoordinatorImpl : NSObject <BeaconBluetoothCoordinator, SharedServiceProvider>

+ (instancetype)sharedInstance;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
