//
//  TouchProbeDebugViewController.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/11/6.
//

#import "TouchProbeDebugViewController.h"
#import "TouchProbeView.h"

@interface TouchProbeDebugViewController ()
@property (nonatomic, strong) UILabel *tipsLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UIButton *hiddenButton;
@property (nonatomic, strong) UIButton *alphaButton;
@property (nonatomic, strong) UIButton *interactionButton;
@property (nonatomic, strong) UIButton *clipsButton;
@property (nonatomic, strong) TouchProbeView *rootProbeView;
@property (nonatomic, strong) TouchProbeView *middleProbeView;
@property (nonatomic, strong) TouchProbeView *innerProbeView;
@property (nonatomic, strong) TouchProbeView *overlapProbeView;
@end

@implementation TouchProbeDebugViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Touch Probe";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                      target:self
                                                      action:@selector(closeAction)];

    [self buildStaticUI];
    [self buildProbeHierarchy];
    [self resetExperimentState];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGFloat width = self.view.bounds.size.width - 32.0;
    CGFloat contentTop = safeTop + 12.0;

    self.tipsLabel.frame = CGRectMake(16.0, contentTop, width, 64.0);

    CGFloat probeHeight = MIN(360.0, self.view.bounds.size.height - contentTop - 250.0);
    self.rootProbeView.frame = CGRectMake(16.0, CGRectGetMaxY(self.tipsLabel.frame) + 12.0, width, probeHeight);

    CGFloat rootWidth = CGRectGetWidth(self.rootProbeView.bounds);
    self.middleProbeView.frame = CGRectMake(20.0, 88.0, MIN(220.0, rootWidth - 48.0), 170.0);
    self.innerProbeView.frame = CGRectMake(CGRectGetWidth(self.middleProbeView.bounds) - 30.0, 100.0, 120.0, 90.0);
    self.overlapProbeView.frame = CGRectMake(MAX(110.0, rootWidth - 170.0), 50.0, 150.0, 120.0);

    self.statusLabel.frame = CGRectMake(16.0, CGRectGetMaxY(self.rootProbeView.frame) + 12.0, width, 72.0);

    CGFloat buttonWidth = (width - 8.0) / 2.0;
    CGFloat buttonY = CGRectGetMaxY(self.statusLabel.frame) + 8.0;
    self.resetButton.frame = CGRectMake(16.0, buttonY, buttonWidth, 40.0);
    self.hiddenButton.frame = CGRectMake(24.0 + buttonWidth, buttonY, buttonWidth, 40.0);

    buttonY += 48.0;
    self.alphaButton.frame = CGRectMake(16.0, buttonY, buttonWidth, 40.0);
    self.interactionButton.frame = CGRectMake(24.0 + buttonWidth, buttonY, buttonWidth, 40.0);

    buttonY += 48.0;
    self.clipsButton.frame = CGRectMake(16.0, buttonY, width, 40.0);
}

- (void)buildStaticUI {
    self.tipsLabel = [[UILabel alloc] init];
    self.tipsLabel.numberOfLines = 0;
    self.tipsLabel.font = [UIFont systemFontOfSize:13.0];
    self.tipsLabel.textColor = UIColor.secondaryLabelColor;
    self.tipsLabel.text = @"橙色视图是最后添加的兄弟视图，重叠区域默认优先命中它，用来验证 hitTest 倒序遍历。蓝色视图故意超出绿色父视图边界，用来验证 pointInside 的默认命中范围。";
    [self.view addSubview:self.tipsLabel];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.font = [UIFont systemFontOfSize:12.0];
    self.statusLabel.textColor = UIColor.labelColor;
    [self.view addSubview:self.statusLabel];

    self.resetButton = [self probeButtonWithTitle:@"重置实验" action:@selector(resetAction)];
    self.hiddenButton = [self probeButtonWithTitle:@"切换 hidden" action:@selector(toggleHiddenAction)];
    self.alphaButton = [self probeButtonWithTitle:@"切换 alpha<0.01" action:@selector(toggleAlphaAction)];
    self.interactionButton = [self probeButtonWithTitle:@"切换 userInteraction" action:@selector(toggleInteractionAction)];
    self.clipsButton = [self probeButtonWithTitle:@"切换父视图 clipsToBounds" action:@selector(toggleClipsAction)];

    [self.view addSubview:self.resetButton];
    [self.view addSubview:self.hiddenButton];
    [self.view addSubview:self.alphaButton];
    [self.view addSubview:self.interactionButton];
    [self.view addSubview:self.clipsButton];
}

- (void)buildProbeHierarchy {
    self.rootProbeView = [self probeViewWithName:@"Root-红色容器" color:UIColor.systemRedColor];
    self.middleProbeView = [self probeViewWithName:@"Middle-绿色父视图" color:UIColor.systemGreenColor];
    self.innerProbeView = [self probeViewWithName:@"Inner-蓝色子视图(部分超界)" color:UIColor.systemBlueColor];
    self.overlapProbeView = [self probeViewWithName:@"Overlap-橙色兄弟视图(最上层)" color:UIColor.systemOrangeColor];

    [self.middleProbeView addSubview:self.innerProbeView];
    [self.rootProbeView addSubview:self.middleProbeView];
    [self.rootProbeView addSubview:self.overlapProbeView];
    [self.view addSubview:self.rootProbeView];
}

- (TouchProbeView *)probeViewWithName:(NSString *)name color:(UIColor *)color {
    TouchProbeView *probeView = [[TouchProbeView alloc] init];
    probeView.probeName = name;
    probeView.backgroundColor = [color colorWithAlphaComponent:0.18];
    probeView.layer.borderWidth = 2.0;
    probeView.layer.borderColor = color.CGColor;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(8.0, 8.0, 240.0, 36.0)];
    label.text = name;
    label.font = [UIFont boldSystemFontOfSize:12.0];
    label.textColor = color;
    label.numberOfLines = 2;
    label.userInteractionEnabled = NO;
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [probeView addSubview:label];

    return probeView;
}

- (UIButton *)probeButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.layer.cornerRadius = 8.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = UIColor.systemGray4Color.CGColor;
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)resetExperimentState {
    self.overlapProbeView.hidden = NO;
    self.overlapProbeView.alpha = 1.0;
    self.overlapProbeView.userInteractionEnabled = YES;
    self.middleProbeView.clipsToBounds = NO;
    [self updateStatusText];
}

- (void)updateStatusText {
    self.statusLabel.text = [NSString stringWithFormat:
                             @"当前状态\n"
                             @"1. Overlap hidden=%@\n"
                             @"2. Overlap alpha=%.3f, userInteraction=%@\n"
                             @"3. Middle clipsToBounds=%@（默认不改变命中边界，只影响显示裁剪）",
                             self.overlapProbeView.hidden ? @"YES" : @"NO",
                             self.overlapProbeView.alpha,
                             self.overlapProbeView.userInteractionEnabled ? @"YES" : @"NO",
                             self.middleProbeView.clipsToBounds ? @"YES" : @"NO"];
}

- (void)resetAction {
    [self resetExperimentState];
    NSLog(@"[TouchProbeDebug] reset");
}

- (void)toggleHiddenAction {
    self.overlapProbeView.hidden = !self.overlapProbeView.hidden;
    [self updateStatusText];
    NSLog(@"[TouchProbeDebug] overlap.hidden=%d", self.overlapProbeView.hidden);
}

- (void)toggleAlphaAction {
    self.overlapProbeView.alpha = self.overlapProbeView.alpha < 0.01 ? 1.0 : 0.005;
    [self updateStatusText];
    NSLog(@"[TouchProbeDebug] overlap.alpha=%.3f", self.overlapProbeView.alpha);
}

- (void)toggleInteractionAction {
    self.overlapProbeView.userInteractionEnabled = !self.overlapProbeView.userInteractionEnabled;
    [self updateStatusText];
    NSLog(@"[TouchProbeDebug] overlap.userInteractionEnabled=%d", self.overlapProbeView.userInteractionEnabled);
}

- (void)toggleClipsAction {
    self.middleProbeView.clipsToBounds = !self.middleProbeView.clipsToBounds;
    [self updateStatusText];
    NSLog(@"[TouchProbeDebug] middle.clipsToBounds=%d", self.middleProbeView.clipsToBounds);
}

- (void)closeAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
