//
//  RouterEmptyProxy.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/9.
//

#import "RouterEmptyProxy.h"

@implementation RouterEmptyProxy
{
    Protocol *_proto;
}

- (instancetype)initWithProtocol:(Protocol *)proto{
    _proto = proto;
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel{
    return [NSMethodSignature signatureWithObjCTypes:@"@@:"];
}

- (void)forwardInvocation:(NSInvocation *)invocation{
    NSLog(@"⚠️ 服务未注册，调用被吞：%@", NSStringFromSelector(invocation.selector));
    const char *retType = invocation.methodSignature.methodReturnType;
    if (retType[0] == 'v') {
           // void 方法，不用设
       } else if (retType[0] == 'B' || retType[0] == 'c') {
           // BOOL 方法（比如 isLoggedIn），返回 NO
           BOOL result = NO;
           [invocation setReturnValue:&result];
       } else if (retType[0] == 'i' || retType[0] == 'q') {
           // NSInteger / int，返回 0
           NSInteger result = 0;
           [invocation setReturnValue:&result];
       } else if (retType[0] == '@') {
           // 对象方法（比如 currentToken），返回 nil
           id result = nil;
           [invocation setReturnValue:&result];
       }
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol{
    return [NSStringFromProtocol(aProtocol) isEqualToString:NSStringFromProtocol(_proto)];
}

@end
