//
//  VehicleAccessService.h
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VehicleAccessService <NSObject>

- (nullable NSDictionary<NSString *, NSString *> *)preferredAuthorizedDeviceFromCandidates:(NSArray<NSDictionary<NSString *, NSString *> *> *)candidates
                                                                           rejectionReason:(NSString * _Nullable * _Nullable)rejectionReason;

@end

NS_ASSUME_NONNULL_END
