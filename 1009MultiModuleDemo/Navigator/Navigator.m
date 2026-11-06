//
//  Navigator.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/19.
//

#import "Navigator.h"
#import "TargetActionMediator.h"

NSString * const NavigatorDefaultScheme = @"multimoduledemo";

@interface Navigator ()

@end

@implementation Navigator

+ (NSSet<NSString *> *)allowedRoutes {
    return [NSSet setWithArray:@[
        @"Login/isLoggedIn",
        @"Login/loginInfo",
        @"Debug/touchProbe"
    ]];
}

+ (BOOL)isRouteAllowedTarget:(NSString *)targetName action:(NSString *)actionName {
    if (targetName.length == 0 || actionName.length == 0) {
        return NO;
    }
    NSString *routeKey = [NSString stringWithFormat:@"%@/%@", targetName, actionName];
    return [[self allowedRoutes] containsObject:routeKey];
}

+ (BOOL)canOpenURL:(NSURL *)url {
    if (![url isKindOfClass:[NSURL class]]) {
        return NO;
    }
    if (url.scheme.length == 0 || url.host.length == 0) {
        return NO;
    }
    return [url.scheme.lowercaseString isEqualToString:NavigatorDefaultScheme];
}

+ (id)openURL:(NSURL *)url {
    if (![self canOpenURL:url]) {
        return nil;
    }

    NSString *targetName = url.host ?: @"";
    NSString *actionName = [self actionNameFromURL:url];
    if (targetName.length == 0 || actionName.length == 0) {
        return nil;
    }
    if (![self isRouteAllowedTarget:targetName action:actionName]) {
        return @{
            @"error" : @"route_not_allowed",
            @"target" : targetName,
            @"action" : actionName
        };
    }

    NSMutableDictionary<NSString *, id> *params = [[self queryParamsFromURL:url] mutableCopy];
    params[@"_url"] = url.absoluteString ?: @"";
    params[@"_scheme"] = url.scheme ?: @"";

    return [self performTarget:targetName action:actionName params:params];
}

+ (id)openURLString:(NSString *)urlString {
    if (urlString.length == 0) {
        return nil;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        return nil;
    }
    return [self openURL:url];
}

+ (id)performTarget:(NSString *)targetName
             action:(NSString *)actionName
             params:(NSDictionary<NSString *,id> *)params {
    return [TargetActionMediator performTarget:targetName
                                        action:actionName
                                        params:params];
}

+ (NSString *)actionNameFromURL:(NSURL *)url {
    NSArray<NSString *> *pathComponents = url.pathComponents ?: @[];
    for (NSString *component in pathComponents) {
        if (component.length > 0 && ![component isEqualToString:@"/"]) {
            return component;
        }
    }
    return @"";
}

+ (NSDictionary<NSString *, id> *)queryParamsFromURL:(NSURL *)url {
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSMutableDictionary<NSString *, id> *params = [NSMutableDictionary dictionary];

    for (NSURLQueryItem *item in components.queryItems ?: @[]) {
        if (item.name.length == 0) {
            continue;
        }
        params[item.name] = item.value ?: @"";
    }

    return [params copy];
}

@end
