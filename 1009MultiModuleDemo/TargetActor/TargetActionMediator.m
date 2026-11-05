//
//  TargetActionMediator.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/19.
//

#import "TargetActionMediator.h"

@implementation TargetActionMediator

+ (id)invokeTarget:(id)target selector:(SEL)selector params:(NSDictionary<NSString *, id> *)params {
    IMP imp = [target methodForSelector:selector];
    id (*func)(id, SEL, NSDictionary *) = (void *)imp;
    return func(target, selector, params ?: @{});
}

+ (id)performTarget:(NSString *)targetName
             action:(NSString *)actionName
             params:(NSDictionary<NSString *,id> *)params {
    if (targetName.length == 0 || actionName.length == 0) {
        return nil;
    }

    NSString *className = [NSString stringWithFormat:@"Target_%@", targetName];
    NSString *selectorName = [NSString stringWithFormat:@"Action_%@:", actionName];

    Class targetClass = NSClassFromString(className);
    if (!targetClass) {
        return @{
            @"error" : @"target_not_found",
            @"target" : targetName,
            @"action" : actionName
        };
    }

    id target = [[targetClass alloc] init];
    SEL action = NSSelectorFromString(selectorName);
    if ([target respondsToSelector:action]) {
        return [self invokeTarget:target selector:action params:params];
    }

    SEL notFoundAction = NSSelectorFromString(@"Action_notFound:");
    if ([target respondsToSelector:notFoundAction]) {
        NSMutableDictionary<NSString *, id> *fallbackParams = [NSMutableDictionary dictionaryWithDictionary:params ?: @{}];
        fallbackParams[@"target"] = targetName;
        fallbackParams[@"action"] = actionName;
        return [self invokeTarget:target selector:notFoundAction params:[fallbackParams copy]];
    }

    return @{
        @"error" : @"action_not_found",
        @"target" : targetName,
        @"action" : actionName
    };
}

@end
