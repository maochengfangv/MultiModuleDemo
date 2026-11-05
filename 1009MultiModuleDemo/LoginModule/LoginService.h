//
//  LoginService.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/9.
//

#ifndef LoginService_h
#define LoginService_h

@protocol LoginService <NSObject>

- (BOOL)isLoggedIn;
- (NSString *)currentToken;
- (void)loginWithPhone:(NSString *)phone completion:(void(^)(NSError *))completion;

@end

#endif /* LoginService_h */
