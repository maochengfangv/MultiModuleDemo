//
//  Target_Debug.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/11/6.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Target_Debug : NSObject

- (id)Action_touchProbe:(NSDictionary<NSString *, id> *)params;
- (id)Action_notFound:(NSDictionary<NSString *, id> *)params;

@end

NS_ASSUME_NONNULL_END
