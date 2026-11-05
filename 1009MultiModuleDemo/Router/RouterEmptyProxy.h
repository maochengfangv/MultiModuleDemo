//
//  RouterEmptyProxy.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RouterEmptyProxy : NSProxy
- (instancetype)initWithProtocol:(Protocol *)proto;
@end

NS_ASSUME_NONNULL_END
