//
//  Target_Debug.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/11/6.
//

#import "Target_Debug.h"
#import "TouchProbeDebugViewController.h"
#import <UIKit/UIKit.h>

@implementation Target_Debug

- (id)Action_touchProbe:(NSDictionary<NSString *, id> *)params {
#if DEBUG
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *topViewController = [self probe_topViewController];
        if (!topViewController) {
            return;
        }

        if ([topViewController isKindOfClass:[TouchProbeDebugViewController class]]) {
            return;
        }

        if ([topViewController isKindOfClass:[UINavigationController class]]) {
            UIViewController *visible = ((UINavigationController *)topViewController).topViewController;
            if ([visible isKindOfClass:[TouchProbeDebugViewController class]]) {
                return;
            }
        }

        TouchProbeDebugViewController *debugViewController = [[TouchProbeDebugViewController alloc] init];
        UINavigationController *navigationController =
            [[UINavigationController alloc] initWithRootViewController:debugViewController];
        navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
        [topViewController presentViewController:navigationController animated:YES completion:nil];
    });

    return @{
        @"target" : @"Debug",
        @"action" : @"touchProbe",
        @"status" : @"presenting"
    };
#else
    return @{
        @"error" : @"debug_only",
        @"message" : @"TouchProbe 调试页仅在 DEBUG 构建下开放"
    };
#endif
}

- (id)Action_notFound:(NSDictionary<NSString *, id> *)params {
    return @{
        @"error" : @"action_not_found",
        @"target" : params[@"target"] ?: @"Debug",
        @"action" : params[@"action"] ?: @"",
        @"message" : @"Debug Target 已命中，但 Action 未开放"
    };
}

- (UIWindow *)probe_activeKeyWindow {
    UIApplication *application = UIApplication.sharedApplication;

    for (UIScene *scene in application.connectedScenes) {
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

        if (windowScene.windows.count > 0) {
            return windowScene.windows.firstObject;
        }
    }

    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.windows.count > 0) {
            return windowScene.windows.firstObject;
        }
    }

    return nil;
}

- (UIViewController *)probe_topViewController {
    UIWindow *window = [self probe_activeKeyWindow];
    UIViewController *topViewController = window.rootViewController;
    if (!topViewController) {
        return nil;
    }

    BOOL keepFinding = YES;
    while (keepFinding) {
        keepFinding = NO;

        if (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
            keepFinding = YES;
            continue;
        }

        if ([topViewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *navigationController = (UINavigationController *)topViewController;
            if (navigationController.topViewController) {
                topViewController = navigationController.topViewController;
                keepFinding = YES;
                continue;
            }
        }

        if ([topViewController isKindOfClass:[UITabBarController class]]) {
            UITabBarController *tabBarController = (UITabBarController *)topViewController;
            if (tabBarController.selectedViewController) {
                topViewController = tabBarController.selectedViewController;
                keepFinding = YES;
                continue;
            }
        }
    }

    return topViewController;
}

@end
