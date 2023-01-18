#import "RtckitPlugin.h"
#import <WFAVEngineKit/WFAVEngineKit.h>
#import <WFChatUIKit/WFCUVideoViewController.h>
#import <WFChatUIKit/WFCUMultiVideoViewController.h>


@interface RtckitPlugin () <WFAVEngineDelegate>
@property(nonatomic, strong)FlutterMethodChannel* channel;

@property(nonatomic, strong) AVAudioPlayer *audioPlayer;
@property(nonatomic, strong) UILocalNotification *localCallNotification;
@end

@implementation RtckitPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"rtckit"
            binaryMessenger:[registrar messenger]];
  RtckitPlugin* instance = [[RtckitPlugin alloc] init];
    instance.channel = channel;
  [registrar addMethodCallDelegate:instance channel:channel];
  [WFAVEngineKit notRegisterVoipPushService];
  [WFAVEngineKit sharedEngineKit].delegate = instance;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *selName = [NSString stringWithFormat:@"%@:result:", call.method];
    SEL sel = NSSelectorFromString(selName);
    if ([self respondsToSelector:sel]) {
        [self performSelector:sel withObject:call.arguments withObject:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)initProto:(NSDictionary *)dict result:(FlutterResult)result {
    result(nil);
}

- (void)addICEServer:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *url = dict[@"url"];
    NSString *name = dict[@"name"];
    NSString *password = dict[@"password"];
    [[WFAVEngineKit sharedEngineKit] addIceServer:url userName:name password:password];
}

- (void)startSingleCall:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    BOOL audioOnly = [dict[@"audioOnly"] boolValue];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"WFCCConversation");
        id obj = [cls performSelector:@selector(singleConversation:) withObject:userId];
        WFCUVideoViewController *videoVC = [[WFCUVideoViewController alloc] initWithTargets:@[userId] conversation:obj audioOnly:audioOnly];
        [[WFAVEngineKit sharedEngineKit] presentViewController:videoVC];
    });
}

- (void)startMultiCall:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *groupId = dict[@"groupId"];
    NSArray<NSString *> *participants = dict[@"participants"];
    BOOL audioOnly = [dict[@"audioOnly"] boolValue];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"WFCCConversation");
        id obj = [cls performSelector:@selector(groupConversation:) withObject:groupId];
        
        UIViewController *videoVC = [[WFCUMultiVideoViewController alloc] initWithTargets:participants conversation:obj audioOnly:audioOnly];
        [[WFAVEngineKit sharedEngineKit] presentViewController:videoVC];
    });
}
#pragma mark - WFAVEngineDelegate
- (void)didReceiveCall:(WFAVCallSession *_Nonnull)session {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([WFAVEngineKit sharedEngineKit].currentSession.state != kWFAVEngineStateIncomming && [WFAVEngineKit sharedEngineKit].currentSession.state != kWFAVEngineStateConnected && [WFAVEngineKit sharedEngineKit].currentSession.state != kWFAVEngineStateConnecting) {
            return;
        }
        
        UIViewController *videoVC;
        if (session.isMultiCall) {
            videoVC = [[WFCUMultiVideoViewController alloc] initWithSession:session];
        } else {
            videoVC = [[WFCUVideoViewController alloc] initWithSession:session];
        }
        
        [[WFAVEngineKit sharedEngineKit] presentViewController:videoVC];
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            if(self.localCallNotification) {
                [[UIApplication sharedApplication] scheduleLocalNotification:self.localCallNotification];
            }
            self.localCallNotification = [[UILocalNotification alloc] init];
            self.localCallNotification.alertBody = @"来电话了";
            self.localCallNotification.soundName = @"ring.caf";
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] scheduleLocalNotification:self.localCallNotification];
            });
        } else {
            self.localCallNotification = nil;
        }
    });
}

- (void)shouldStartRing:(BOOL)isIncoming {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([WFAVEngineKit sharedEngineKit].currentSession.state == kWFAVEngineStateIncomming || [WFAVEngineKit sharedEngineKit].currentSession.state == kWFAVEngineStateOutgoing) {
            if([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
                AudioServicesAddSystemSoundCompletion(kSystemSoundID_Vibrate, NULL, NULL, systemAudioCallback, NULL);
                AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
            } else {
                AVAudioSession *audioSession = [AVAudioSession sharedInstance];
                //默认情况按静音或者锁屏键会静音
                [audioSession setCategory:AVAudioSessionCategorySoloAmbient error:nil];
                [audioSession setActive:YES error:nil];
                
                if (self.audioPlayer) {
                    [self shouldStopRing];
                }
                
                NSURL *url = [[NSBundle mainBundle] URLForResource:@"ring" withExtension:@"caf"];
                NSError *error = nil;
                self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
                if (!error) {
                    self.audioPlayer.numberOfLoops = -1;
                    self.audioPlayer.volume = 1.0;
                    [self.audioPlayer prepareToPlay];
                    [self.audioPlayer play];
                }
            }
        }
    });
}

void systemAudioCallback (SystemSoundID soundID, void* clientData) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            if ([WFAVEngineKit sharedEngineKit].currentSession.state == kWFAVEngineStateIncomming) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            }
        }
    });
}

- (void)shouldStopRing {
    if (self.audioPlayer) {
        [self.audioPlayer stop];
        self.audioPlayer = nil;
        [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    }
}

- (void)didCallEnded:(WFAVCallEndReason) reason duration:(int)callDuration {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            if(self.localCallNotification) {
                [[UIApplication sharedApplication] cancelLocalNotification:self.localCallNotification];
                self.localCallNotification = nil;
            }
            
            if(reason == kWFAVCallEndReasonTimeout || (reason == kWFAVCallEndReasonRemoteHangup && callDuration == 0)) {
                UILocalNotification *callEndNotification = [[UILocalNotification alloc] init];
                if(reason == kWFAVCallEndReasonTimeout) {
                    callEndNotification.alertBody = @"来电未接听";
                } else {
                    callEndNotification.alertBody = @"来电已取消";
                }
                if (@available(iOS 8.2, *)) {
                    self.localCallNotification.alertTitle = @"网络通话";
                }
                
                //应该播放挂断的声音
    //            self.localCallNotification.soundName = @"ring.caf";
                [[UIApplication sharedApplication] scheduleLocalNotification:callEndNotification];
            }
        }
    });
}

- (void)didReceiveIncomingPushWithPayload:(PKPushPayload * _Nonnull )payload
                                  forType:(NSString * _Nonnull )type {
    
}
@end
