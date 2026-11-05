//
//  Target_Login.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/19.
//

#import "Target_Login.h"
#import "Router.h"
#import "LoginService.h"

@implementation Target_Login

- (id)Action_isLoggedIn:(NSDictionary<NSString *, id> *)params {
    id<LoginService> loginService = [[Router shared] sericeForProtocol:@protocol(LoginService)];
    return @([loginService isLoggedIn]);
}

- (id)Action_loginInfo:(NSDictionary<NSString *, id> *)params {
    id<LoginService> loginService = [[Router shared] sericeForProtocol:@protocol(LoginService)];
    NSString *phone = params[@"phone"] ?: @"";
    NSString *token = [loginService currentToken] ?: @"";
    return @{
        @"target" : @"Login",
        @"action" : @"loginInfo",
        @"phone" : phone,
        @"loggedIn" : @([loginService isLoggedIn]),
        @"token" : token
    };
}

- (id)Action_notFound:(NSDictionary<NSString *, id> *)params {
    return @{
        @"error" : @"action_not_found",
        @"target" : params[@"target"] ?: @"Login",
        @"action" : params[@"action"] ?: @"",
        @"message" : @"Target 已命中，但 Action 未开放"
    };
}

@end
