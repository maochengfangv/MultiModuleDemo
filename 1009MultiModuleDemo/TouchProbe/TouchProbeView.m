//
//  TouchProbeView.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/11/6.
//

#import "TouchProbeView.h"

@implementation TouchProbeView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    NSLog(@"[hitTest] 进入 %@ inside=%d hidden=%d alpha=%.2f uie=%d clips=%d",
          self.probeName, [self pointInside:point withEvent:event],
          self.hidden, self.alpha, self.userInteractionEnabled, self.clipsToBounds);
    UIView *hit = [super hitTest:point withEvent:event];
    NSLog(@"[hitTest] %@ 命中 -> %@", self.probeName, NSStringFromClass(hit.class));
    return hit;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    BOOL inside = [super pointInside:point withEvent:event];
    NSLog(@"[pointInside] %@ point=%@ inside=%d", self.probeName, NSStringFromCGPoint(point), inside);
    return inside;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSLog(@"[touchesBegan] %@ next=%@", self.probeName, NSStringFromClass(self.nextResponder.class));
    [super touchesBegan:touches withEvent:event];
}
// touchesMoved / touchesEnded / touchesCancelled 同理

@end
