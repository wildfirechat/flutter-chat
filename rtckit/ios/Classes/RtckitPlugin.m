#import "RtckitPlugin.h"
#import <Flutter/Flutter.h>
#import "FLNativeView.h"
#import <WFAVEngineKit/WFAVEngineKit.h>


@interface WFCallSessionDelegater : NSObject<WFAVCallSessionDelegate>
@property(nonatomic, strong)WFAVCallSession *callSession;
@property(nonatomic, strong)FlutterMethodChannel* channel;
@property(nonatomic, weak)NSMutableDictionary<NSString*, WFCallSessionDelegater*>* delegaters;
@property(nonatomic, weak)NSMutableDictionary<NSNumber*, FLNativeView*>* videoViews;

- (instancetype)initWithSession:(WFAVCallSession *)callSession channel:(FlutterMethodChannel *)channel delegaters:(NSMutableDictionary<NSString*, WFCallSessionDelegater*> *)delegaters videoViews:(NSMutableDictionary<NSNumber*, FLNativeView*> *)videoViews;
@end

@implementation WFCallSessionDelegater
- (instancetype)initWithSession:(WFAVCallSession *)callSession channel:(FlutterMethodChannel *)channel delegaters:(NSMutableDictionary<NSString*, WFCallSessionDelegater*> *)delegaters videoViews:(NSMutableDictionary<NSNumber*, FLNativeView*> *)videoViews {
    self = [super init];
    if(self) {
        self.callSession = callSession;
        self.channel = channel;
        self.delegaters = delegaters;
        self.videoViews = videoViews;
        if(callSession) {
            [self.delegaters setValue:self forKey:callSession.callId];
        }
    }
    return self;
}

-(void)setCallSession:(WFAVCallSession *)callSession {
    _callSession = callSession;
    [self.delegaters setValue:self forKey:callSession.callId];
}

- (void)didCallEndWithReason:(WFAVCallEndReason)reason {
    [self.delegaters removeObjectForKey:self.callSession.callId];
    [self.channel invokeMethod:@"didCallEndWithReason" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"reason":@(reason)}];
    if([[WFAVEngineKit sharedEngineKit].currentSession.callId isEqualToString:self.callSession.callId]) {
        [self.delegaters removeAllObjects];
        [self.videoViews removeAllObjects];
    }
}

- (void)didChangeInitiator:(NSString * _Nullable)initiator { 
    [self.channel invokeMethod:@"didChangeInitiator" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"initiator":initiator}];
}

- (void)didChangeMode:(BOOL)isAudioOnly { 
    [self.channel invokeMethod:@"didChangeMode" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"isAudioOnly":@(isAudioOnly)}];
}

- (void)didChangeState:(WFAVEngineState)state { 
    if(self.callSession) {
        [self.channel invokeMethod:@"didChangeState" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"state":@(state)}];
    }
}

- (void)didCreateLocalVideoTrack:(RTCVideoTrack * _Nonnull)localVideoTrack { 
    [self.channel invokeMethod:@"didCreateLocalVideoTrack" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession]}];
}

- (void)didError:(NSError * _Nonnull)error { 
    [self.channel invokeMethod:@"didError" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"error":error.localizedDescription}];
}

- (void)didGetStats:(NSArray * _Nonnull)stats { 
//    [self.channel invokeMethod:@"didGetStats" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession]}];
}

- (void)didParticipantConnected:(NSString * _Nonnull)userId screenSharing:(BOOL)screenSharing { 
    [self.channel invokeMethod:@"didParticipantConnected" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"userId":userId, @"screenSharing":@(screenSharing)}];
}

- (void)didParticipantJoined:(NSString * _Nonnull)userId screenSharing:(BOOL)screenSharing { 
    [self.channel invokeMethod:@"didParticipantJoined" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"userId":userId, @"screenSharing":@(screenSharing)}];
}

- (void)didParticipantLeft:(NSString * _Nonnull)userId screenSharing:(BOOL)screenSharing withReason:(WFAVCallEndReason)reason { 
    [self.channel invokeMethod:@"didParticipantLeft" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"userId":userId, @"screenSharing":@(screenSharing), @"reason":@(reason)}];
}

- (void)didReceiveRemoteVideoTrack:(RTCVideoTrack * _Nonnull)remoteVideoTrack fromUser:(NSString * _Nonnull)userId screenSharing:(BOOL)screenSharing { 
    [self.channel invokeMethod:@"didReceiveRemoteVideoTrack" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"userId":userId, @"screenSharing":@(screenSharing)}];
}

- (void)didVideoMuted:(BOOL)videoMuted fromUser:(NSString * _Nonnull)userId { 
    [self.channel invokeMethod:@"didVideoMuted" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"userId":userId, @"videoMuted":@(videoMuted)}];
}

- (void)didReportAudioVolume:(NSInteger)volume ofUser:(NSString *_Nonnull)userId {
    [self.channel invokeMethod:@"didReportAudioVolume" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"userId":userId, @"volume":@(volume)}];
}

- (void)didChangeType:(BOOL)audience ofUser:(NSString *_Nonnull)userId {
    [self.channel invokeMethod:@"didChangeType" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"userId":userId, @"audience":@(audience)}];
}

- (void)didChangeAudioRoute {
    [self.channel invokeMethod:@"didChangeAudioRoute" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession]}];
}

- (void)didMuteStateChanged:(NSArray<NSString *> *_Nonnull)userIds {
    [self.channel invokeMethod:@"didMuteStateChanged" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"userIds":userIds}];
}

- (void)didMedia:(NSString *_Nullable)media lostPackage:(int)lostPackage screenSharing:(BOOL)screenSharing {
    [self.channel invokeMethod:@"didMediaLost" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"media":media, @"lostPackage":@(lostPackage), @"screenSharing":@(screenSharing)}];
}

- (void)didMedia:(NSString *_Nullable)media lostPackage:(int)lostPackage uplink:(BOOL)uplink ofUser:(NSString *_Nonnull)userId screenSharing:(BOOL)screenSharing {
    [self.channel invokeMethod:@"didRemoteMediaLost" arguments:@{@"callId":self.callSession.callId, @"session":[RtckitPlugin callSession2Dict:self.callSession], @"media":media, @"userId":userId, @"lostPackage":@(lostPackage), @"uplink":@(uplink), @"screenSharing":@(screenSharing)}];
}

- (void)onScreenSharingFailure {

}

//- (RTCVideoFrame *_Nonnull)didCaptureVideoFrame:(RTCVideoFrame *_Nonnull)frame screenSharing:(BOOL)isScreenSharing {
//    
//}

//- (void)didGetStats:(NSArray<RTCLegacyStatsReport *> *_Nonnull)stats ofUser:(NSString *_Nonnull)userId screenSharing:(BOOL)screenSharing {
//    [self.channel invokeMethod:@"didVideoMuted" arguments:@{@"callId":self.callSession.callId, @"userId":userId, @"videoMuted":@(videoMuted)}];
//}
@end


@interface RtckitPlugin () <WFAVEngineDelegate>
@property(nonatomic, strong)FlutterMethodChannel* channel;

@property(nonatomic, strong)NSMutableDictionary<NSString*, WFCallSessionDelegater*>* delegaters;

@property(nonatomic, strong)NSMutableDictionary<NSNumber*, FLNativeView*>* videoViews;
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
    instance.delegaters = [[NSMutableDictionary alloc] init];
    instance.videoViews = [[NSMutableDictionary alloc] init];
    
    FLNativeViewFactory* factory = [[FLNativeViewFactory alloc] initWithMessenger:registrar.messenger maps:instance.videoViews];
    [registrar registerViewFactory:factory withId:@"<platform-view-type>"];
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
    Class cls = NSClassFromString(@"WFCCConversation");
    id obj = [cls performSelector:@selector(singleConversation:) withObject:userId];
    
    WFCallSessionDelegater* delegater = [[WFCallSessionDelegater alloc] initWithSession:nil channel:self.channel delegaters:self.delegaters videoViews:self.videoViews];
    WFAVCallSession *callSession = [[WFAVEngineKit sharedEngineKit] startCall:@[userId] audioOnly:audioOnly callExtra:nil conversation:obj sessionDelegate:delegater];
    delegater.callSession = callSession;
    result([RtckitPlugin callSession2Dict:callSession]);
}

- (void)startMultiCall:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *groupId = dict[@"groupId"];
    NSArray<NSString *> *participants = dict[@"participants"];
    BOOL audioOnly = [dict[@"audioOnly"] boolValue];
    Class cls = NSClassFromString(@"WFCCConversation");
    id obj = [cls performSelector:@selector(groupConversation:) withObject:groupId];
    
    
    WFCallSessionDelegater* delegater = [[WFCallSessionDelegater alloc] initWithSession:nil channel:self.channel delegaters:self.delegaters videoViews:self.videoViews];
    WFAVCallSession *callSession = [[WFAVEngineKit sharedEngineKit] startCall:participants audioOnly:audioOnly callExtra:nil conversation:obj sessionDelegate:delegater];
    delegater.callSession = callSession;
    result([RtckitPlugin callSession2Dict:callSession]);
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
    result([RtckitPlugin callSession2Dict:session]);
}

+ (NSDictionary *)callSession2Dict:(WFAVCallSession *)session {
    if(!session) {
        return nil;
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
    dictionary[@"speaker"] = @(session.speaker);
    dictionary[@"videoMuted"] = @(session.videoMuted);
    dictionary[@"audioMuted"] = @(session.audioMuted);
    dictionary[@"conference"] = @(session.conference);
    dictionary[@"audience"] = @(session.audience);
    dictionary[@"advanced"] = @(session.advanced);
    dictionary[@"multiCall"] = @(session.multiCall);
    
    return dictionary;
}

- (void)setLocalVideoView:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    int viewId = [dict[@"viewId"] intValue];
    FLNativeView* view = self.videoViews[@(viewId)];
    if(view) {
        UIView *container = view.view;
        [[WFAVEngineKit sharedEngineKit].currentSession setupLocalVideoView:container scalingType:kWFAVVideoScalingTypeAspectFit];
    }
    
    result(nil);
}

- (void)setRemoteVideoView:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    NSString *userId = dict[@"userId"];
    BOOL screenSharing = [dict[@"screenSharing"] boolValue];
    int viewId = [dict[@"viewId"] intValue];
    FLNativeView* view = self.videoViews[@(viewId)];
    if(view) {
        UIView *container = view.view;
        [[WFAVEngineKit sharedEngineKit].currentSession setupRemoteVideoView:container scalingType:kWFAVVideoScalingTypeAspectFit forUser:userId screenSharing:screenSharing];
    }
    
    result(nil);
}

- (void)startPreview:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    [[WFAVEngineKit sharedEngineKit] startVideoPreview];
    result(nil);
}

- (void)answerCall:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    BOOL audioOnly = [dict[@"audioOnly"] boolValue];
    WFAVCallSession *session = [WFAVEngineKit sharedEngineKit].currentSession;
    if(session.state == kWFAVEngineStateIncomming) {
        [session answerCall:audioOnly callExtra:nil];
    };
    result(nil);
}

- (void)changeToAudioOnly:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    WFAVCallSession *session = [WFAVEngineKit sharedEngineKit].currentSession;
    if(session.state == kWFAVEngineStateConnected) {
        [session setAudioOnly:YES];
    };
    result(nil);
}

- (void)endCall:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    WFAVCallSession *session = [WFAVEngineKit sharedEngineKit].currentSession;
    if([session.callId isEqualToString:callId]) {
        [session endCall];
    }
    result(nil);
}

- (void)muteAudio:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    BOOL muted = [dict[@"muted"] boolValue];
    [[WFAVEngineKit sharedEngineKit].currentSession muteAudio:muted];
    result(nil);
}

- (void)enableSpeaker:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    BOOL speaker = [dict[@"speaker"] boolValue];
    [[WFAVEngineKit sharedEngineKit].currentSession enableSpeaker:speaker];
    result(nil);
}

- (void)muteVideo:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    BOOL muted = [dict[@"muted"] boolValue];
    [[WFAVEngineKit sharedEngineKit].currentSession muteVideo:muted];
    result(nil);
}

- (void)switchCamera:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    [[WFAVEngineKit sharedEngineKit].currentSession switchCamera];
    result(nil);
}

- (void)getCameraPosition:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    result(@([WFAVEngineKit sharedEngineKit].currentSession.cameraPosition));
}

- (void)isBluetoothSpeaker:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    result(@([WFAVEngineKit sharedEngineKit].currentSession.isBluetoothSpeaker));
}

- (void)isHeadsetPluggedIn:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    result(@([WFAVEngineKit sharedEngineKit].currentSession.isHeadsetPluggedIn));
}

- (void)getParticipantIds:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    result([WFAVEngineKit sharedEngineKit].currentSession.participantIds);
}

- (void)getParticipantProfiles:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *callId = dict[@"callId"];
    NSArray<WFAVParticipantProfile *> *profiles = [WFAVEngineKit sharedEngineKit].currentSession.participants;
    NSMutableArray<NSDictionary *> *dicts = [[NSMutableArray alloc] init];
    [profiles enumerateObjectsUsingBlock:^(WFAVParticipantProfile * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [dicts addObject:[self profile2Dict:obj]];
    }];
    result(dicts);
}

- (NSDictionary *)profile2Dict:(WFAVParticipantProfile *)profile {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    dict[@"userId"] = profile.userId;
    dict[@"startTime"] = @(profile.startTime);
    dict[@"state"] = @(profile.state);
    dict[@"videoMuted"] = @(profile.videoMuted);
    dict[@"audioMuted"] = @(profile.audioMuted);
    dict[@"audience"] = @(profile.audience);
    dict[@"screeSharing"] = @(profile.screeSharing);
    dict[@"callExtra"] = profile.callExtra;
    dict[@"videoType"] = @(profile.videoType);
    
    return dict;
}

#pragma mark - WFAVEngineDelegate
- (void)didReceiveCall:(WFAVCallSession *_Nonnull)session {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([WFAVEngineKit sharedEngineKit].currentSession.state != kWFAVEngineStateIncomming && [WFAVEngineKit sharedEngineKit].currentSession.state != kWFAVEngineStateConnected && [WFAVEngineKit sharedEngineKit].currentSession.state != kWFAVEngineStateConnecting) {
            return;
        }
        
        WFCallSessionDelegater* delegater = [[WFCallSessionDelegater alloc] initWithSession:session channel:self.channel delegaters:self.delegaters videoViews:self.videoViews];
        session.delegate = delegater;
        
        [self.channel invokeMethod:@"didReceiveCallCallback" arguments:@{@"callSession":[RtckitPlugin callSession2Dict:session]}];
    });
}

- (void)shouldStartRing:(BOOL)isIncoming {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([WFAVEngineKit sharedEngineKit].currentSession.state == kWFAVEngineStateIncomming || [WFAVEngineKit sharedEngineKit].currentSession.state == kWFAVEngineStateOutgoing) {
            [self.channel invokeMethod:@"shouldStartRingCallback" arguments:@{@"incoming":@(isIncoming)}];
        }
    });
}

- (void)shouldStopRing {
    [self.channel invokeMethod:@"shouldStopRingCallback" arguments:nil];
}

- (void)didCallEnded:(WFAVCallEndReason) reason duration:(int)callDuration {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.channel invokeMethod:@"didEndCallCallback" arguments:@{@"reason":@(reason), @"duration":@(callDuration)}];
    });
}

- (void)didReceiveIncomingPushWithPayload:(PKPushPayload * _Nonnull )payload
                                  forType:(NSString * _Nonnull )type {
    
}
@end
