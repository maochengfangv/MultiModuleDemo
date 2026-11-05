//
//  PerformanceServiceImpl.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/11/5.
//

#import <Foundation/Foundation.h>
#import "PerformanceService.h"
#import "SharedServiceProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface PerformanceServiceImpl : NSObject <PerformanceService, SharedServiceProvider>

@end

NS_ASSUME_NONNULL_END
