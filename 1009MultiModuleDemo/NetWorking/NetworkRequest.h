//
//  NetworkRequest.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/12.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef  NS_ENUM(NSUInteger, NetworkHTTPMethod) {
    NetworkHTTPMethodGET = 0,
    NetworkHTTPMethodPOST,
    NetworkHTTPMethodPUT,
    NetworkHTTPMethodDELETE,
    NetworkHTTPMethodPATCH
};

@interface NetworkRequest : NSObject<NSCopying>

@property (nonatomic, assign) NetworkHTTPMethod method;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy, nullable) NSString *absoluteURLString;
@property (nonatomic,copy, nullable) NSDictionary<NSString *, id> *parameters;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, assign) BOOL usesJSONRequestSerializer;

+ (instancetype)requestWithMethod:(NetworkHTTPMethod)method path:(NSString *)path parameters:(nullable NSDictionary<NSString *, id> *)parameters;


@end

NS_ASSUME_NONNULL_END
