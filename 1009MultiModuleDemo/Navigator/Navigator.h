//
//  Navigator.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const NavigatorDefaultScheme;

@interface Navigator : NSObject

+ (BOOL)canOpenURL:(NSURL *)url;
+ (id _Nullable)openURL:(NSURL *)url;
+ (id _Nullable)openURLString:(NSString *)urlString;

+ (id _Nullable)performTarget:(NSString *)targetName
                       action:(NSString *)actionName
                       params:(nullable NSDictionary<NSString *, id> *)params;

@end

NS_ASSUME_NONNULL_END
