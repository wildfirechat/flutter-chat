#import "RtckitPlugin.h"
#import <WFAVEngineKit/WFAVEngineKit.h>
#import <WFChatUIKit/WFCUVideoViewController.h>
#import <WFChatUIKit/WFCUMultiVideoViewController.h>
#import "AppService.h"

@interface RtckitPlugin () <WFAVEngineDelegate>
@property(nonatomic, strong)FlutterMethodChannel* channel;

@property(nonatomic, strong) AVAudioPlayer *audioPlayer;
//@property(nonatomic, strong) UILocalNotification *localCallNotification;
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
  [WFCUConfigManager globalManager].appServiceProvider = [AppService sharedAppService];
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

-(void) getMaxVideoCallCount:(NSDictionary *)dict result:(FlutterResult)result {
    result(@([WFAVEngineKit sharedEngineKit].maxVideoCallCount));
}

-(void) getMaxAudioCallCount:(NSDictionary *)dict result:(FlutterResult)result {
    result(@([WFAVEngineKit sharedEngineKit].maxAudioCallCount));
}

-(void) seMaxVideoCallCount:(NSDictionary *)dict result:(FlutterResult)result {
    [WFAVEngineKit sharedEngineKit].maxVideoCallCount = [dict[@"count"] intValue];
    result(nil);
}

-(void) seMaxAudioCallCount:(NSDictionary *)dict result:(FlutterResult)result {
    [WFAVEngineKit sharedEngineKit].maxVideoCallCount = [dict[@"count"] intValue];
    result(nil);
}

- (void)addICEServer:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *url = dict[@"url"];
    NSString *name = dict[@"name"];
    NSString *password = dict[@"password"];
    [[WFAVEngineKit sharedEngineKit] addIceServer:url userName:name password:password];
    result(nil);
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
    result(nil);
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
    result(nil);
}

- (void)setupAppServer:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *appServerAddress = dict[@"appServerAddress"];
    NSString *authToken = dict[@"authToken"];
    [[AppService sharedAppService] setServerAddress:appServerAddress];
    [[AppService sharedAppService] setAppAuthToken:authToken];
    result(nil);
}

- (void)showConferenceInfo:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *conferenceId = dict[@"conferenceId"];
    NSString *password = dict[@"password"];
    WFZConferenceInfoViewController *vc = [[WFZConferenceInfoViewController alloc] init];
    vc.conferenceId = conferenceId;
    vc.password = password;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[WFAVEngineKit sharedEngineKit] presentViewController:vc];
    });
    result(nil);
}

- (void)showConferencePortal:(NSDictionary *)dict result:(FlutterResult)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        WFZHomeViewController *vc = [[WFZHomeViewController alloc] init];
        vc.isPresent = YES;
        UINavigationController *nv = [[UINavigationController alloc] initWithRootViewController:vc];
        nv.modalPresentationStyle = UIModalPresentationFullScreen;
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:nv animated:YES completion:nil];
    });
    result(nil);
}

- (void)isSupportMultiCall:(NSDictionary *)dict result:(FlutterResult)result {
    result(@(YES));
}

- (void)isSupportConference:(NSDictionary *)dict result:(FlutterResult)result {
    result(@([WFAVEngineKit sharedEngineKit].supportConference));
}

- (void)setVideoProfile:(NSDictionary *)dict result:(FlutterResult)result {
    int profile = [dict[@"profile"] intValue];
    BOOL swapWidthHeight = [dict[@"swapWidthHeight"] boolValue];
    [[WFAVEngineKit sharedEngineKit] setVideoProfile:profile swapWidthHeight:swapWidthHeight];
    result(nil);
}

- (void)currentCallSession:(NSDictionary *)dict result:(FlutterResult)result {
    WFAVCallSession *session = [WFAVEngineKit sharedEngineKit].currentSession;
    if(!session || session.state == kWFAVEngineStateIdle) {
        result(nil);
        return;
    }
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    dictionary[@"callId"] = session.callId;
    if(session.initiator.length) {
        dictionary[@"initiator"] = session.initiator;
    }
    if(session.inviter.length) {
        dictionary[@"inviter"] = session.inviter;
    }
    dictionary[@"state"] = @(session.state);
    dictionary[@"startTime"] = @(session.startTime);
    dictionary[@"connectedTime"] = @(session.connectedTime);
    dictionary[@"endTime"] = @(session.endTime);
    if(session.conversation) {
        dictionary[@"conversation"] = session.conversationJson;
    }
    dictionary[@"audioOnly"] = @(session.audioOnly);
    dictionary[@"endReason"] = @(session.endReason);
    dictionary[@"conference"] = @(session.conference);
    dictionary[@"audience"] = @(session.audience);
    dictionary[@"advanced"] = @(session.advanced);
    dictionary[@"multiCall"] = @(session.multiCall);
    result(dictionary);
}

- (void)answerCall:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL audioOnly = [dict[@"audioOnly"] boolValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        WFAVCallSession *session = [WFAVEngineKit sharedEngineKit].currentSession;
        if(session.state == kWFAVEngineStateIncomming) {
            [session answerCall:audioOnly callExtra:nil];
        };
    });
    result(nil);
}

- (void)endCall:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    dispatch_async(dispatch_get_main_queue(), ^{
        WFAVCallSession *session = [WFAVEngineKit sharedEngineKit].currentSession;
        if([session.callId isEqualToString:callId]) {
            [session endCall];
        }
    });
    result(nil);
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
//        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
//            self.localCallNotification = [[UILocalNotification alloc] init];
//            self.localCallNotification.alertBody = @"来电话了";
//            self.localCallNotification.soundName = @"ring.caf";
//            
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [[UIApplication sharedApplication] scheduleLocalNotification:self.localCallNotification];
//            });
//        } else {
//            self.localCallNotification = nil;
//        }
        [self.channel invokeMethod:@"didReceiveCallCallback" arguments:@{@"callId":[WFAVEngineKit sharedEngineKit].currentSession.callId}];
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
            [self.channel invokeMethod:@"shouldStartRingCallback" arguments:@{@"incoming":@(isIncoming)}];
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
    }
    [self.channel invokeMethod:@"shouldStopRingCallback" arguments:nil];
}

- (void)didCallEnded:(WFAVCallEndReason) reason duration:(int)callDuration {
    dispatch_async(dispatch_get_main_queue(), ^{
//        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
//            if(self.localCallNotification) {
//                [[UIApplication sharedApplication] cancelLocalNotification:self.localCallNotification];
//                self.localCallNotification = nil;
//            }
//            
//            if(reason == kWFAVCallEndReasonTimeout || (reason == kWFAVCallEndReasonRemoteHangup && callDuration == 0)) {
//                UILocalNotification *callEndNotification = [[UILocalNotification alloc] init];
//                if(reason == kWFAVCallEndReasonTimeout) {
//                    callEndNotification.alertBody = @"来电未接听";
//                } else {
//                    callEndNotification.alertBody = @"来电已取消";
//                }
//                if (@available(iOS 8.2, *)) {
//                    self.localCallNotification.alertTitle = @"网络通话";
//                }
//                
//                //应该播放挂断的声音
//    //            self.localCallNotification.soundName = @"ring.caf";
//                [[UIApplication sharedApplication] scheduleLocalNotification:callEndNotification];
//            }
//        }
        [self.channel invokeMethod:@"didEndCallCallback" arguments:@{@"reason":@(reason), @"duration":@(callDuration)}];
    });
}

- (void)didReceiveIncomingPushWithPayload:(PKPushPayload * _Nonnull )payload
                                  forType:(NSString * _Nonnull )type {
    
}
@end
