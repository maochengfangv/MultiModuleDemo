//
//  NetworkRequest.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/12.
//

#import "NetworkRequest.h"

static const NSTimeInterval kNetworkRequestDefaultTimeout = 15.0;

@implementation NetworkRequest

+ (instancetype)requestWithMethod:(NetworkHTTPMethod)method path:(NSString *)path parameters:(NSDictionary<NSString *,id> *)parameters {
    
    NetworkRequest *request = [[self alloc] init];
    request.method = method;
    request.path = path ?: @"";
    request.parameters = parameters;
    request.timeoutInterval = kNetworkRequestDefaultTimeout;
    request.usesJSONRequestSerializer = YES;
    return  request;
}

- (id)copyWithZone:(NSZone *)zone {
    NetworkRequest *request = [[[self class] allocWithZone:zone] init];
    request.method = self.method;
    request.path = [self.path copy];
    request.absoluteURLString = [self.absoluteURLString copy];
    request.parameters = [self.parameters copy];
    request.headers = [self.headers copy];
    request.timeoutInterval = self.timeoutInterval;
    request.usesJSONRequestSerializer = self.usesJSONRequestSerializer;
    return request;
}

@end
