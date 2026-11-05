//
//  Router.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/9.
//

#import "Router.h"
#import "RouterEmptyProxy.h"
#import "SharedServiceProvider.h"

@interface Router ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, Class> *registry;
@end

@implementation Router

+(instancetype)shared{
    static Router *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype) init{
    if (self = [super init]){
        _registry = [NSMutableDictionary dictionary];
    }
    return self;
}

// 注册 LoginServiceImpl 在 +load 调用
- (void)registerProtocol:(Protocol *)proto impl:(Class)implClass{
    @synchronized (self) {
        [self.registry setObject:implClass forKey:NSStringFromProtocol(proto)];
    }
}

- (id)sericeForProtocol:(Protocol *)proto{
    Class implClass;
    @synchronized (self) {
        implClass = self.registry[NSStringFromProtocol(proto)];
    }
    
    if (!implClass){
        return [[RouterEmptyProxy alloc] initWithProtocol:proto];
    }
    
    SEL sharedSelector = @selector(sharedInstance);
    if ([implClass conformsToProtocol:@protocol(SharedServiceProvider)] &&
        [implClass respondsToSelector:sharedSelector]) {
        Class<SharedServiceProvider> sharedClass = (Class<SharedServiceProvider>)implClass;
        return [sharedClass sharedInstance];
    }
    
    return [[implClass alloc] init];
}

@end
