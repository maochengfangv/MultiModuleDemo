//
//  VehicleAccessServiceImpl.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/10.
//

#import "VehicleAccessServiceImpl.h"
#import "Router.h"

@implementation VehicleAccessServiceImpl

+ (void)load {
    [[Router shared] registerProtocol:@protocol(VehicleAccessService) impl:[self class]];
}

- (NSDictionary<NSString *,NSString *> *)preferredAuthorizedDeviceFromCandidates:(NSArray<NSDictionary<NSString *,NSString *> *> *)candidates
                                                                 rejectionReason:(NSString * _Nullable __autoreleasing *)rejectionReason {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *connectable = [NSMutableArray array];
    for (NSDictionary<NSString *, NSString *> *item in candidates) {
        if ([item[@"isConnectable"] isEqualToString:@"YES"]) {
            [connectable addObject:item];
        }
    }

    if (connectable.count == 0) {
        if (rejectionReason) {
            *rejectionReason = @"尚未发现可连接车辆";
        }
        return nil;
    }

    if (connectable.count > 1) {
        if (rejectionReason) {
            *rejectionReason = @"检测到多台候选车辆，已禁止自动解锁";
        }
        return nil;
    }

    NSDictionary<NSString *, NSString *> *device = connectable.firstObject;
    NSArray<NSString *> *authorizedIdentifiers = [[NSUserDefaults standardUserDefaults] arrayForKey:@"authorized_vehicle_identifiers"];

    if (authorizedIdentifiers.count == 0) {
        return device;
    }

    if (![authorizedIdentifiers containsObject:device[@"identifier"] ?: @""]) {
        if (rejectionReason) {
            *rejectionReason = @"当前账号对该车辆无解锁权限";
        }
        return nil;
    }

    return device;
}

@end
