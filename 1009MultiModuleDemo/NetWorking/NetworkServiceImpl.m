//
//  NetworkServiceImpl.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/12.
//

#import "NetworkServiceImpl.h"
#import <AFNetworking/AFNetworking.h>
#import "Router.h"

static NSString * const NetworkServiceErrorDomain = @"com.demo.network.service";

@interface NetworkServiceImpl ()

@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *defaultHeaders;
@property (nonatomic, copy, nullable) NSString *baseURLString;

@end

@implementation NetworkServiceImpl

+ (void)load{
    [[Router shared] registerProtocol:@protocol(NetworkService) impl:[self class]];
}

+ (instancetype)sharedInstance{
    static NetworkServiceImpl *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc]init];
    });
    return instance;
}

- (instancetype)init{
    self = [super init];
    
    if(self){
        _defaultHeaders = [NSMutableDictionary dictionary];
        _baseURLString =  [[[NSUserDefaults standardUserDefaults] stringForKey:@"network_base_url"] copy];
        _sessionManager = [self buildSessionManager];
    }
    return self;
}

- (AFHTTPSessionManager *)buildSessionManager {
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithBaseURL:nil];
    AFJSONResponseSerializer *jsonSerializer = [AFJSONResponseSerializer serializer];
    NSMutableSet *acceptableType = [NSMutableSet setWithSet:jsonSerializer.acceptableContentTypes ? :[NSSet set]];
    [acceptableType addObjectsFromArray:@[@"application/json", @"text/json", @"text/plain", @"text/html"]];
    jsonSerializer.acceptableContentTypes = acceptableType;
    
    AFHTTPResponseSerializer *rawSerializer = [AFHTTPResponseSerializer serializer];
    manager.responseSerializer = [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:@[jsonSerializer, rawSerializer]];
    return manager;
}

- (NSURLSessionDataTask *)sendRequest:(NetworkRequest *)request
                           completion:(NetworkServiceCompletion)completion {
    NSString *urlString = [self resolvedURLStringForRequest:request];
    if (urlString.length == 0) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:NetworkServiceErrorDomain
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey : @"请求 URL 不能为空"}];
            completion(nil, nil, error);
        }
        return nil;
    }

    AFHTTPRequestSerializer *serializer = request.usesJSONRequestSerializer ? [AFJSONRequestSerializer serializer] : [AFHTTPRequestSerializer serializer];
    serializer.timeoutInterval = request.timeoutInterval > 0 ? request.timeoutInterval : 15.0;

    NSDictionary<NSString *, NSString *> *headers = [self mergedHeadersForRequest:request];
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        [serializer setValue:obj forHTTPHeaderField:key];
    }];

    NSError *serializationError = nil;
    NSMutableURLRequest *urlRequest = [serializer requestWithMethod:[self stringForMethod:request.method]
                                                          URLString:urlString
                                                         parameters:request.parameters
                                                              error:&serializationError];
    if (serializationError) {
        if (completion) {
            completion(nil, nil, serializationError);
        }
        return nil;
    }

    NSURLSessionDataTask *task = [self.sessionManager dataTaskWithRequest:urlRequest
                                                           uploadProgress:nil
                                                         downloadProgress:nil
                                                        completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        if (completion) {
            NSHTTPURLResponse *httpResponse = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
            completion(httpResponse, responseObject, error);
        }
    }];
    [task resume];
    return task;
}

- (void)updateBaseURLString:(NSString *)baseURLString {
    @synchronized (self) {
        _baseURLString = [baseURLString copy];
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (baseURLString.length > 0) {
        [defaults setObject:baseURLString forKey:@"network_base_url"];
    } else {
        [defaults removeObjectForKey:@"network_base_url"];
    }
    [defaults synchronize];
}

- (void)setDefaultHeaderValue:(NSString *)value forField:(NSString *)field {
    if (field.length == 0) {
        return;
    }

    @synchronized (self) {
        if (value.length > 0) {
            self.defaultHeaders[field] = value;
        } else {
            [self.defaultHeaders removeObjectForKey:field];
        }
    }
}

- (void)removeDefaultHeaderForField:(NSString *)field {
    if (field.length == 0) {
        return;
    }

    @synchronized (self) {
        [self.defaultHeaders removeObjectForKey:field];
    }
}

- (NSDictionary<NSString *, NSString *> *)mergedHeadersForRequest:(NetworkRequest *)request {
    NSMutableDictionary<NSString *, NSString *> *headers = [NSMutableDictionary dictionary];
    
    @synchronized (self) {
        [headers addEntriesFromDictionary:self.defaultHeaders];
    }
    
    if (request.headers.count > 0){
        [headers addEntriesFromDictionary:request.headers];
    }
    
    return [headers copy];
}

- (NSString *)resolvedURLStringForRequest:(NetworkRequest *)request {
    if (request.absoluteURLString.length > 0) {
        return request.absoluteURLString;
    }

    if ([request.path hasPrefix:@"http://"] || [request.path hasPrefix:@"https://"]) {
        return request.path;
    }

    NSString *baseURL = nil;
    @synchronized (self) {
        baseURL = self.baseURLString;
    }

    if (baseURL.length == 0) {
        return request.path ?: @"";
    }

    NSString *trimmedBase = [baseURL hasSuffix:@"/"] ? [baseURL substringToIndex:baseURL.length - 1] : baseURL;
    NSString *trimmedPath = [request.path hasPrefix:@"/"] ? [request.path substringFromIndex:1] : request.path;
    return trimmedPath.length > 0 ? [NSString stringWithFormat:@"%@/%@", trimmedBase, trimmedPath] : trimmedBase;
}

- (NSString *)stringForMethod:(NetworkHTTPMethod)method {
    switch (method) {
        case NetworkHTTPMethodGET:
            return @"GET";
        case NetworkHTTPMethodPOST:
            return @"POST";
        case NetworkHTTPMethodPUT:
            return @"PUT";
        case NetworkHTTPMethodDELETE:
            return @"DELETE";
        case NetworkHTTPMethodPATCH:
            return @"PATCH";
    }
    return @"GET";
}

@end
