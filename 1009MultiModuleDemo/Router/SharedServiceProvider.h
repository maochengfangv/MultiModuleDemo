//
//   SharedServiceProvider.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SharedServiceProvider <NSObject>

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
