//
//  ViewController.m
//  1009MultiModuleDemo
//
//  Created by maochengfang on 2026/10/9.
//

#import "ViewController.h"
#import "Router.h"
#import "LoginService.h"
#import "BeaconBluetoothCoordinator.h"
#import "NetworkService.h"
#import "TargetActionMediator.h"
#import "Navigator.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UILabel *beaconStatusLabel;
@property (nonatomic, strong) UILabel *bluetoothStatusLabel;
@property (nonatomic, strong) UILabel *audioStatusLabel;
@property (nonatomic, strong) UITextField *commandTextField;
@property (nonatomic, strong) UIButton *scanButton;
@property (nonatomic, strong) UIButton *streamButton;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *> *devices;
@property (nonatomic, strong) id<BeaconBluetoothCoordinator> coordinator;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.devices = @[];

//    id<LoginService> login = [[Router shared] sericeForProtocol:@protocol(LoginService)];
//    NSLog(@"isLoggedIn--->  %d", [login isLoggedIn]);

    [self buildUI];
    [self setupCoordinator];
//    [self testNetWorking];
//    [self testTargetAction];
//    [self testScheme];
}

- (void)testTargetAction {
    id result = [TargetActionMediator performTarget:@"Login" action:@"isLoggedIn" params:nil];
    BOOL loggedIn = [result boolValue];

    id info = [TargetActionMediator performTarget:@"Login"
                                           action:@"loginInfo"
                                           params:@{@"phone": @"13800138000"}];
    NSLog(@"%@", info);
}

- (void)testScheme{
    id result = [Navigator openURLString:@"multimoduledemo://Login/loginInfo?phone=13800138000"];
    NSLog(@"-----> %@", result);
}

- (void)testNetWorking {
    id<NetworkService> service = [[Router shared] sericeForProtocol:@protocol(NetworkService)];
    [service updateBaseURLString:@"http://101.132.90.7:10018"];
    NetworkRequest *request = [NetworkRequest requestWithMethod:NetworkHTTPMethodPOST path:@"auth/v3.1/user/sendVerifiyCode" parameters:@{@"type": @"text",@"mobile":@"8186008872"}];
    request.headers = @{
        @"sourceChannel": @"",
        @"packageName": @"com.mexico.universal",
        @"version": @"1.0.0",
        @"adid": @"",
        @"idfa": @"",
        @"userId": @"",
        @"uuId": @""
    };
    [service sendRequest:request completion:^(NSHTTPURLResponse * _Nullable response, id  _Nullable responseObject, NSError * _Nullable error) {
        NSLog(@"");
    }];
    
}

- (void)setupCoordinator {
    self.coordinator = [[Router shared] sericeForProtocol:@protocol(BeaconBluetoothCoordinator)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleCoordinatorStateChanged:) name:BeaconBluetoothCoordinatorStateDidChangeNotification object:nil];
    [self.coordinator requestLocationAuthorizationAndStartMonitoring];
    [self applyCoordinatorState:nil];
}

- (void)buildUI {
    CGFloat width = self.view.bounds.size.width - 32.0;

    self.beaconStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 88, width, 48)];
    self.beaconStatusLabel.numberOfLines = 0;
    self.beaconStatusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [self.view addSubview:self.beaconStatusLabel];

    self.bluetoothStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 144, width, 66)];
    self.bluetoothStatusLabel.numberOfLines = 0;
    self.bluetoothStatusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [self.view addSubview:self.bluetoothStatusLabel];

    self.audioStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 216, width, 48)];
    self.audioStatusLabel.numberOfLines = 0;
    self.audioStatusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [self.view addSubview:self.audioStatusLabel];

    self.scanButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.scanButton.frame = CGRectMake(16, 276, 120, 40);
    [self.scanButton setTitle:@"开始扫描" forState:UIControlStateNormal];
    [self.scanButton addTarget:self action:@selector(toggleScanAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.scanButton];

    self.streamButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.streamButton.frame = CGRectMake(152, 276, 120, 40);
    [self.streamButton setTitle:@"启动音频流" forState:UIControlStateNormal];
    [self.streamButton addTarget:self action:@selector(toggleMockAudioStreamAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.streamButton];

    self.commandTextField = [[UITextField alloc] initWithFrame:CGRectMake(16, 328, width - 108, 40)];
    self.commandTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.commandTextField.placeholder = @"输入 HEX 指令，例如 AA55010203";
    self.commandTextField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.commandTextField.delegate = self;
    [self.view addSubview:self.commandTextField];

    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(CGRectGetMaxX(self.commandTextField.frame) + 8, 328, 100, 40);
    [self.sendButton setTitle:@"发送指令" forState:UIControlStateNormal];
    [self.sendButton addTarget:self action:@selector(sendCommandAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.sendButton];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 384, self.view.bounds.size.width, self.view.bounds.size.height - 384) style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"device_cell"];
    [self.view addSubview:self.tableView];
}

- (void)applyCoordinatorState:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo ?: @{};
    self.beaconStatusLabel.text = userInfo[BeaconBluetoothCoordinatorBeaconStatusKey] ?: [self.coordinator currentBeaconStatus];
    self.bluetoothStatusLabel.text = userInfo[BeaconBluetoothCoordinatorBluetoothStatusKey] ?: [self.coordinator currentBluetoothStatus];
    self.audioStatusLabel.text = userInfo[BeaconBluetoothCoordinatorAudioStatusKey] ?: [self.coordinator currentAudioStatus];
    self.devices = userInfo[BeaconBluetoothCoordinatorDevicesKey] ?: [self.coordinator currentDevices];
    [self.tableView reloadData];
    [self.scanButton setTitle:[self.coordinator isScanning] ? @"停止扫描" : @"开始扫描" forState:UIControlStateNormal];
    [self.streamButton setTitle:[self.coordinator isStreamingAudio] ? @"停止音频流" : @"启动音频流" forState:UIControlStateNormal];
}

- (void)handleCoordinatorStateChanged:(NSNotification *)notification {
    [self applyCoordinatorState:notification];
}


- (void)toggleScanAction {
    [self.coordinator toggleManualScan];
    [self applyCoordinatorState:nil];
}

- (void)sendCommandAction {
    [self.commandTextField resignFirstResponder];
    [self.coordinator sendHexCommand:self.commandTextField.text ?: @""];
}

- (void)toggleMockAudioStreamAction {
    [self.coordinator toggleMockAudioStreaming];
    [self applyCoordinatorState:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.devices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"device_cell" forIndexPath:indexPath];
    NSDictionary<NSString *, NSString *> *device = self.devices[indexPath.row];
    NSString *name = device[@"name"].length > 0 ? device[@"name"] : @"未命名设备";
    NSString *rssi = device[@"rssi"] ?: @"-";
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.text = [NSString stringWithFormat:@"%@\n%@\nRSSI: %@", name, device[@"identifier"], rssi];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary<NSString *, NSString *> *device = self.devices[indexPath.row];
    NSString *identifier = device[@"identifier"];
    if (identifier.length == 0) {
        return;
    }
    [self.coordinator connectDeviceWithIdentifier:[[NSUUID alloc] initWithUUIDString:identifier]];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendCommandAction];
    return YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BeaconBluetoothCoordinatorStateDidChangeNotification object:nil];
}

@end
