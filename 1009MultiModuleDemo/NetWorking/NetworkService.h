//
//  NetworkService.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/12.
//

#import <Foundation/Foundation.h>
#import "NetworkRequest.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^NetworkServiceCompletion)(NSHTTPURLResponse * _Nullable response,
                                        id _Nullable responseObject,
                                        NSError * _Nullable error);

@protocol NetworkService <NSObject>

- (nullable NSURLSessionDataTask *)sendRequest:(NetworkRequest *)request
                                    completion:(NetworkServiceCompletion)completion;

- (void)updateBaseURLString:(nullable NSString *)baseURLString;
- (void)setDefaultHeaderValue:(nullable NSString *)value forField:(NSString *)field;
- (void)removeDefaultHeaderForField:(NSString *)field;

@end

NS_ASSUME_NONNULL_END
