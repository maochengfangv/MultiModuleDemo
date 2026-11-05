//
//  Router.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Router : NSObject

+ (instancetype)shared;

// 注册 协议 -> 实现类
- (void)registerProtocol:(Protocol *) proto impl:(Class)implClass;
// 查找根据协议拿实例
- (id)sericeForProtocol:(Protocol *)proto;

@end

NS_ASSUME_NONNULL_END
