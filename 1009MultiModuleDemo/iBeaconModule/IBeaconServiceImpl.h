//
//  IBeaconServiceImpl.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/9.
//

#import <Foundation/Foundation.h>
#import "IBeaconService.h"
#import "SharedServiceProvider.h"
NS_ASSUME_NONNULL_BEGIN

@interface IBeaconServiceImpl : NSObject<IBeaconService, SharedServiceProvider>

@property (nonatomic, weak, nullable) id<IBeaconServiceDelegate>delegate;

+ (instancetype)sharedInstance;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
