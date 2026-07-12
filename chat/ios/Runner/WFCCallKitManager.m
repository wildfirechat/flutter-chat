//
//  WFCCallKitManager.m
//  Runner
//
//  CallKit integration for incoming VOIP calls.
//

#import "WFCCallKitManager.h"
#import <AVFoundation/AVFoundation.h>

@interface WFCCallKitManager ()
@property(nonatomic, strong) FlutterMethodChannel *channel;
@property(nonatomic, strong) CXProvider *provider;
@property(nonatomic, strong) CXCallController *callController;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSUUID *> *callUUIDDict;
@property(nonatomic, strong) PKPushRegistry *pushRegistry;
@end

@implementation WFCCallKitManager

- (instancetype)initWithMethodChannel:(FlutterMethodChannel *)channel {
    self = [super init];
    if (self) {
        _channel = channel;
        _callUUIDDict = [NSMutableDictionary dictionary];
        
        CXProviderConfiguration *config = [[CXProviderConfiguration alloc] initWithLocalizedName:@"野火IM"];
        config.supportsVideo = YES;
        config.maximumCallsPerCallGroup = 1;
        config.maximumCallGroups = 1;
        config.supportedHandleTypes = [NSSet setWithObjects:@(CXHandleTypeGeneric), @(CXHandleTypePhoneNumber), nil];
        
        UIImage *icon = [UIImage imageNamed:@"callkit_app_icon"];
        if (icon) {
            config.iconTemplateImageData = UIImagePNGRepresentation(icon);
        }
        
        _provider = [[CXProvider alloc] initWithConfiguration:config];
        [_provider setDelegate:self queue:nil];
        _callController = [[CXCallController alloc] initWithQueue:dispatch_get_main_queue()];
    }
    return self;
}

- (void)registerVoipPush {
    self.pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    self.pushRegistry.delegate = self;
    self.pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
}

#pragma mark - Public

- (void)reportIncomingCallWithCallId:(NSString *)callId
                            callerId:(NSString *)callerId
                          callerName:(NSString *)callerName
                           audioOnly:(BOOL)audioOnly {
    if (!callId.length) return;
    
    NSUUID *uuid = self.callUUIDDict[callId];
    if (!uuid) {
        uuid = [NSUUID UUID];
        self.callUUIDDict[callId] = uuid;
    }
    
    CXCallUpdate *update = [[CXCallUpdate alloc] init];
    update.supportsDTMF = NO;
    update.supportsHolding = NO;
    update.supportsGrouping = NO;
    update.supportsUngrouping = NO;
    update.hasVideo = !audioOnly;
    update.remoteHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:callerId ?: @""];
    update.localizedCallerName = callerName.length ? callerName : callerId;
    
    [self.provider reportNewIncomingCallWithUUID:uuid update:update completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[WFCCallKitManager] reportNewIncomingCall error: %@", error);
        }
    }];
}

- (void)reportCallConnected:(NSString *)callId {
    if (!callId.length) return;
    NSUUID *uuid = self.callUUIDDict[callId];
    if (uuid) {
        CXTransaction *transaction = [[CXTransaction alloc] initWithAction:[[CXAnswerCallAction alloc] initWithCallUUID:uuid]];
        [self.callController requestTransaction:transaction completion:^(NSError * _Nullable error) {
            if (error) NSLog(@"[WFCCallKitManager] reportCallConnected error: %@", error);
        }];
    }
}

- (void)reportCallEnded:(NSString *)callId {
    if (!callId.length) return;
    NSUUID *uuid = self.callUUIDDict[callId];
    if (uuid) {
        [self.provider reportCallWithUUID:uuid endedAtDate:nil reason:CXCallEndedReasonRemoteEnded];
        [self.callUUIDDict removeObjectForKey:callId];
    }
}

#pragma mark - PKPushRegistryDelegate

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type {
    if (![type isEqualToString:PKPushTypeVoIP]) return;
    
    const unsigned char *bytes = credentials.token.bytes;
    NSMutableString *token = [NSMutableString stringWithCapacity:credentials.token.length * 2];
    for (NSUInteger i = 0; i < credentials.token.length; i++) {
        [token appendFormat:@"%02x", bytes[i]];
    }
    
    [self.channel invokeMethod:@"didUpdateVoipToken" arguments:@{@"token": [token copy]}];
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type {
    if (![type isEqualToString:PKPushTypeVoIP]) return;
    
    NSDictionary *wfc = payload.dictionaryPayload[@"wfc"];
    if (!wfc) return;
    
    NSString *sender = wfc[@"sender"];
    NSString *senderName = wfc[@"senderName"];
    NSString *pushData = wfc[@"pushData"];
    
    BOOL audioOnly = YES;
    NSString *callId = nil;
    if (pushData.length) {
        NSData *data = [pushData dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *pd = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        if (pd) {
            audioOnly = [pd[@"audioOnly"] boolValue];
            callId = pd[@"callId"];
        }
    }
    
    [self reportIncomingCallWithCallId:callId callerId:sender callerName:senderName audioOnly:audioOnly];
    
    [self.channel invokeMethod:@"didReceiveIncomingPush" arguments:@{
        @"callId": callId ?: @"",
        @"callerId": sender ?: @"",
        @"callerName": senderName ?: @"",
        @"audioOnly": @(audioOnly)
    }];
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(NSString *)type {
    // No-op
}

#pragma mark - CXProviderDelegate

- (void)providerDidReset:(CXProvider *)provider {
    NSLog(@"[WFCCallKitManager] providerDidReset");
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action {
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeVoiceChat error:nil];
    [action fulfill];
    
    NSString *callId = [self callIdForUUID:action.callUUID];
    [self.channel invokeMethod:@"performAnswerCall" arguments:@{@"callId": callId ?: @""}];
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    NSString *callId = [self callIdForUUID:action.callUUID];
    [action fulfill];
    [self.channel invokeMethod:@"performEndCall" arguments:@{@"callId": callId ?: @""}];
    if (callId) {
        [self.callUUIDDict removeObjectForKey:callId];
    }
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action {
    NSString *callId = [self callIdForUUID:action.callUUID];
    [action fulfill];
    [self.channel invokeMethod:@"didChangeCallMute" arguments:@{
        @"callId": callId ?: @"",
        @"muted": @(action.isMuted)
    }];
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
    // Audio session is ready; Dart side handles the actual call answer.
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession {
    // No-op
}

#pragma mark - Helpers

- (NSString *)callIdForUUID:(NSUUID *)uuid {
    for (NSString *callId in self.callUUIDDict) {
        if ([self.callUUIDDict[callId] isEqual:uuid]) {
            return callId;
        }
    }
    return nil;
}

@end
