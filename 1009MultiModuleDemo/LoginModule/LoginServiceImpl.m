//
//  LoginServiceImpl.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/9.
//

#import "LoginServiceImpl.h"
#import "Router.h"

@implementation LoginServiceImpl

+ (void)load{
    [[Router shared] registerProtocol:@protocol(LoginService) impl:[self class]];
}

- (BOOL)isLoggedIn{
    return [[[NSUserDefaults standardUserDefaults] stringForKey:@"user_token"] length] > 0;
}

- (NSString *)currentToken{
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"user_token"];
}

- (void)loginWithPhone:(NSString *)phone completion:(void (^)(NSError *))completion{
    
}

@end
