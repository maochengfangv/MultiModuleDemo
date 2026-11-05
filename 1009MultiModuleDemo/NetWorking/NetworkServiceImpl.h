//
//  NetworkServiceImpl.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/12.
//

#import <Foundation/Foundation.h>
#import "NetworkService.h"
#import "SharedServiceProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface NetworkServiceImpl : NSObject<NetworkService, SharedServiceProvider>

@end

NS_ASSUME_NONNULL_END
