#import "AppDelegate.h"
#import "GeneratedPluginRegistrant.h"
#if USE_CALL_KIT
#import "WFCCallKitManager.h"
#endif
#import <AVFoundation/AVFoundation.h>
#import <UserNotifications/UserNotifications.h>
#include <WFChatClient/WFCChatClient.h>

static NSString * const kShareAppGroupId = @"group.cn.wildfirechat.messangerEx";
static NSString * const kShareItemsKey = @"wfc_share_items";
static NSString * const kSharedConversationsKey = @"wfc_share_conversation_list";
static NSString * const kSharedAuthTokenKey = @"wfc_share_appservice_auth_token";
static NSString * const kSharedAppServerAddressKey = @"wfc_share_appserver_address";

@interface AppDelegate () <UNUserNotificationCenterDelegate>
#if USE_CALL_KIT
@property(nonatomic, strong) WFCCallKitManager *callKitManager;
#endif
@property(nonatomic, strong) FlutterMethodChannel *shareChannel;
@property(nonatomic, strong) NSArray<NSDictionary *> *pendingShareItems;
// 播放语音消息期间的距离传感器(贴耳切听筒/息屏)
@property(nonatomic, strong) FlutterMethodChannel *proximityChannel;
@property(nonatomic, assign) BOOL proximityMonitoring;
// 兜底超时，防止 Flutter 侧没来得及 stop 时贴近息屏一直生效(与 Android 侧的 wake lock 超时对齐)
@property(nonatomic, strong) NSTimer *proximityTimeoutTimer;
// 播放语音消息前查当前音频输出设备(有没有接耳机)
@property(nonatomic, strong) FlutterMethodChannel *audioOutputChannel;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [GeneratedPluginRegistrant registerWithRegistry:self];

    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;

    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
                              if (granted) {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      [[UIApplication sharedApplication] registerForRemoteNotifications];
                                  });
                                  
                              } else {
                              }
                          }];

    BOOL result = [super application:application didFinishLaunchingWithOptions:launchOptions];
    
    if (result) {
        FlutterViewController *controller = (FlutterViewController *)self.window.rootViewController;
#if USE_CALL_KIT
        FlutterMethodChannel *callKitChannel = [FlutterMethodChannel
            methodChannelWithName:@"chat.wildfire/callkit"
                  binaryMessenger:controller.binaryMessenger];
        self.callKitManager = [[WFCCallKitManager alloc] initWithMethodChannel:callKitChannel];
        [self.callKitManager registerVoipPush];
#endif
        
        self.shareChannel = [FlutterMethodChannel
            methodChannelWithName:@"chat.wildfire/share"
                  binaryMessenger:controller.binaryMessenger];
        [self.shareChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
            if ([call.method isEqualToString:@"getPendingShareItems"]) {
                result(self.pendingShareItems ?: @[]);
                self.pendingShareItems = nil;
            } else if ([call.method isEqualToString:@"saveSharedConversations"]) {
                [self saveSharedConversations:call.arguments];
                result(@"OK");
            } else {
                result(FlutterMethodNotImplemented);
            }
        }];

        [self setupProximityChannel:controller];
        [self setupAudioOutputChannel:controller];
    }

    return result;
}

#pragma mark - 距离传感器

// 兜底超时。语音消息最长 60 秒，正常播完 Flutter 侧就会 stop；真漏了的话
// proximityMonitoringEnabled 是全局的，之后在 App 里任何地方贴近手机都会息屏。
static const NSTimeInterval kProximityMonitoringTimeout = 10 * 60;

// 播放语音消息时用。iOS 打开 proximityMonitoring 之后，贴近时系统自己会息屏，
// 我们只把远近变化报给 Flutter 侧，由它决定切听筒还是扬声器。
- (void)setupProximityChannel:(FlutterViewController *)controller {
    self.proximityChannel = [FlutterMethodChannel
        methodChannelWithName:@"chat.wildfire/proximity"
              binaryMessenger:controller.binaryMessenger];
    __weak typeof(self) weakSelf = self;
    [self.proximityChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
        if ([call.method isEqualToString:@"start"]) {
            result(@([weakSelf startProximityMonitoring]));
        } else if ([call.method isEqualToString:@"stop"]) {
            [weakSelf stopProximityMonitoring];
            result(nil);
        } else {
            result(FlutterMethodNotImplemented);
        }
    }];
}

/// @return 是否真的开始监听。没有距离传感器的设备(如 iPad)打开后依然是 NO，Flutter 侧据此不做自动切换。
- (BOOL)startProximityMonitoring {
    if (self.proximityMonitoring) {
        return YES;
    }
    UIDevice *device = [UIDevice currentDevice];
    device.proximityMonitoringEnabled = YES;
    if (!device.proximityMonitoringEnabled) {
        return NO;
    }
    self.proximityMonitoring = YES;
    self.proximityTimeoutTimer =
        [NSTimer scheduledTimerWithTimeInterval:kProximityMonitoringTimeout
                                         target:self
                                       selector:@selector(stopProximityMonitoring)
                                       userInfo:nil
                                        repeats:NO];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onProximityStateChanged:)
                                                 name:UIDeviceProximityStateDidChangeNotification
                                               object:device];
    // 开始播放时手机可能已经贴在耳边了，iOS 只在状态变化时才发通知，这里补报一次当前状态
    if (device.proximityState) {
        [self.proximityChannel invokeMethod:@"onProximityChanged" arguments:@YES];
    }
    return YES;
}

- (void)stopProximityMonitoring {
    if (!self.proximityMonitoring) {
        return;
    }
    self.proximityMonitoring = NO;
    [self.proximityTimeoutTimer invalidate];
    self.proximityTimeoutTimer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceProximityStateDidChangeNotification
                                                  object:nil];
    [UIDevice currentDevice].proximityMonitoringEnabled = NO;
}

- (void)onProximityStateChanged:(NSNotification *)notification {
    [self.proximityChannel invokeMethod:@"onProximityChanged"
                              arguments:@([UIDevice currentDevice].proximityState)];
}

#pragma mark - 音频输出设备

// 播放语音消息前查一次：接了耳机就不用距离传感器、也不提示贴近手机。
// 只做一次性查询，不监听路由变化(AVAudioSessionRouteChangeNotification)：语音消息通常
// 只有几秒，播放中途插拔耳机的收益不值得再引入一份监听状态。
- (void)setupAudioOutputChannel:(FlutterViewController *)controller {
    self.audioOutputChannel = [FlutterMethodChannel
        methodChannelWithName:@"chat.wildfire/audio_output"
              binaryMessenger:controller.binaryMessenger];
    __weak typeof(self) weakSelf = self;
    [self.audioOutputChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
        if ([call.method isEqualToString:@"isHeadsetOn"]) {
            result(@([weakSelf isHeadsetOn]));
        } else {
            result(FlutterMethodNotImplemented);
        }
    }];
}

/// 声音会直接进耳朵的输出设备。判断错了只是多提示一句「请贴近手机聆听」，不影响出声。
- (BOOL)isHeadsetOn {
    AVAudioSessionRouteDescription *route = [AVAudioSession sharedInstance].currentRoute;
    for (AVAudioSessionPortDescription *output in route.outputs) {
        NSString *portType = output.portType;
        if ([portType isEqualToString:AVAudioSessionPortHeadphones]
            || [portType isEqualToString:AVAudioSessionPortBluetoothA2DP]
            || [portType isEqualToString:AVAudioSessionPortBluetoothHFP]
            || [portType isEqualToString:AVAudioSessionPortBluetoothLE]
            || [portType isEqualToString:AVAudioSessionPortUSBAudio]
            || [portType isEqualToString:AVAudioSessionPortCarAudio]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    if ([url.scheme isEqualToString:@"wfcchat"] && [url.host isEqualToString:@"share"]) {
        [self loadSharedItems];
        return YES;
    }
    return NO;
}

- (void)saveSharedConversations:(NSDictionary *)arguments {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kShareAppGroupId];
    NSArray *conversations = arguments[@"conversations"];
    NSString *authToken = arguments[@"authToken"];
    NSString *appServerAddress = arguments[@"appServerAddress"];
    if (conversations) {
        [defaults setObject:conversations forKey:kSharedConversationsKey];
    }
    if (authToken.length) {
        [defaults setObject:authToken forKey:kSharedAuthTokenKey];
    }
    if (appServerAddress.length) {
        [defaults setObject:appServerAddress forKey:kSharedAppServerAddressKey];
    }
    [defaults synchronize];
}

- (void)loadSharedItems {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kShareAppGroupId];
    NSArray<NSDictionary *> *items = [defaults objectForKey:kShareItemsKey];
    if (items.count) {
        self.pendingShareItems = items;
        [defaults removeObjectForKey:kShareItemsKey];
    }
    if (self.pendingShareItems.count) {
        [self.shareChannel invokeMethod:@"onShareItemsReceived" arguments:self.pendingShareItems];
    }
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:
(UIUserNotificationSettings *)notificationSettings {
    // register to receive notifications
    [application registerForRemoteNotifications];
}


- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    if ([deviceToken isKindOfClass:[NSData class]]) {
        const unsigned *tokenBytes = [deviceToken bytes];
        NSString *hexToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                              ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                              ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                              ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
        [[WFCCNetworkService sharedInstance] setDeviceToken:hexToken];
    } else {
        NSString *token = [[[[deviceToken description] stringByReplacingOccurrencesOfString:@"<"
                                                                                 withString:@""]
                            stringByReplacingOccurrencesOfString:@">"
                            withString:@""]
                           stringByReplacingOccurrencesOfString:@" "
                           withString:@""];
        
        [[WFCCNetworkService sharedInstance] setDeviceToken:token];
    }
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    
}

@end
