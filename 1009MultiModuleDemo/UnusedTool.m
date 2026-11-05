//
//  UnusedTool.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/20.
//

#import "UnusedTool.h"

@implementation UnusedTool

- (void)unsedFunc{
    NSLog(@"%@-->%@",NSStringFromClass(self.class),NSStringFromSelector(@selector(unsedFunc)));
}

@end
