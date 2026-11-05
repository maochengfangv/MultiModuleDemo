//
//  UIApplication+TouchProbe.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/11/6.
//

#import "UIApplication+TouchProbe.h"

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation UIApplication (TouchProbe)

+ (void)load {
#if DEBUG
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method a = class_getInstanceMethod(self, @selector(sendEvent:));
        Method b = class_getInstanceMethod(self, @selector(probe_sendEvent:));
        method_exchangeImplementations(a, b);
    });
#endif
}

- (UIWindow *)probe_activeKeyWindow {
    for (UIScene *scene in self.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        if (scene.activationState != UISceneActivationStateForegroundActive &&
            scene.activationState != UISceneActivationStateForegroundInactive) {
            continue;
        }
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                return window;
            }
        }
    }

    for (UIScene *scene in self.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                return window;
            }
        }
    }

    return nil;
}

- (void)probe_sendEvent:(UIEvent *)event {
    UITouch *touch = event.allTouches.anyObject;
    if (touch) {
        UIWindow *eventWindow = touch.window;
        UIWindow *activeKeyWindow = [self probe_activeKeyWindow];
        NSLog(@"[sendEvent] phase=%ld eventWindow=%@ activeKeyWindow=%@",
              (long)touch.phase,
              eventWindow ? NSStringFromClass(eventWindow.class) : @"nil",
              activeKeyWindow ? NSStringFromClass(activeKeyWindow.class) : @"nil");
    }
    [self probe_sendEvent:event]; // 原实现
}

@end
