//
//  WFCCallKitManager.m
//  WildFireChat
//
//  Created by Rain on 2022/4/25.
//  Copyright © 2022 WildFireChat. All rights reserved.
//

#import "WFCCallKitManager.h"
#import <CallKit/CallKit.h>
#import <UIKit/UIKit.h>
#import <WFAVEngineKit/WFAVEngineKit.h>
#import "RtckitPlugin.h"

@interface WFCCallKitManager ()
@property(nonatomic, strong) CXProvider *provider;
@property(nonatomic, strong) CXCallController *callController;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSUUID *> *callUUIDDict;
@property(nonatomic, strong)FlutterMethodChannel* channel;
@end

@implementation WFCCallKitManager

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel {
    self = [super init];
    if(self) {
        self.callUUIDDict = [[NSMutableDictionary alloc] init];
        static CXProviderConfiguration* configInternal = nil;
        configInternal = [[CXProviderConfiguration alloc] initWithLocalizedName:@"野火"];
        configInternal.supportsVideo = true;
        configInternal.maximumCallsPerCallGroup = 1;
        configInternal.maximumCallGroups = 1;
        configInternal.supportedHandleTypes = [[NSSet alloc] initWithObjects:[NSNumber numberWithInt:CXHandleTypeGeneric],[NSNumber numberWithInt:CXHandleTypePhoneNumber], nil];
//        UIImage* iconMaskImage = [UIImage imageNamed:@"file_icon"];
//        configInternal.iconTemplateImageData = UIImagePNGRepresentation(iconMaskImage);

        self.provider = [[CXProvider alloc] initWithConfiguration: configInternal];
        [self.provider setDelegate:self queue:dispatch_get_main_queue()];
        self.callController = [[CXCallController alloc] initWithQueue:dispatch_get_main_queue()];
        self.channel = channel;
    }
    return self;
}

- (void)didReceiveCall:(WFAVCallSession *)session {
    if(self.callUUIDDict[session.callId]) {
        session.callUUID = self.callUUIDDict[session.callId];
    } else {
        if(session.state == kWFAVEngineStateIdle) {
            return;
        }
        
        NSUUID *currentCall = [NSUUID UUID];
        session.callUUID = currentCall;
        [self reportIncomingCallWithTitle:[[WFAVEngineKit sharedEngineKit] getUserDisplayName:session.initiator] Sid:session.initiator audioOnly:session.audioOnly callId:session.callId uuid:currentCall];
    }

}
- (void)didCallEnded:(WFAVCallEndReason)reason duration:(int)callDuration {
    if([WFAVEngineKit sharedEngineKit].currentSession.callUUID) {
        CXEndCallAction *endAction = [[CXEndCallAction alloc] initWithCallUUID:[WFAVEngineKit sharedEngineKit].currentSession.callUUID];
        CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endAction];
        [self.callController requestTransaction:transaction completion:^(NSError * _Nullable error) {
            NSLog(@"end call");
        }];
    }
}
- (void)didReceiveIncomingPushWithPayload:(PKPushPayload *)payload
                                  forType:(NSString *)type {
    NSLog(@"didReceiveIncomingPushWithPayload");
    NSDictionary *wfc = payload.dictionaryPayload[@"wfc"];
    if(wfc) {
        NSString *sender = wfc[@"sender"];
        NSString *pushData = wfc[@"pushData"];
        NSDictionary *pd = [NSJSONSerialization JSONObjectWithData:[pushData dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
        BOOL audioOnly = [pd[@"audioOnly"] boolValue];
        NSString *callId = pd[@"callId"];
        [self reportIncomingCallWithTitle:[[WFAVEngineKit sharedEngineKit] getUserDisplayName:sender] Sid:sender audioOnly:audioOnly callId:callId];
    }
}

- (void)reportIncomingCallWithTitle:(NSString *)title Sid:(NSString *)sid audioOnly:(BOOL)audioOnly callId:(NSString *)callId {
    NSUUID *currentCall = [NSUUID UUID];
    [self reportIncomingCallWithTitle:title Sid:sid audioOnly:audioOnly callId:callId uuid:currentCall];
}

- (void)reportIncomingCallWithTitle:(NSString *)title Sid:(NSString *)sid audioOnly:(BOOL)audioOnly callId:(NSString *)callId uuid:(NSUUID *)uuid {
    CXCallUpdate* update = [[CXCallUpdate alloc] init];
    update.supportsDTMF = false;
    update.supportsHolding = false;
    update.supportsGrouping = false;
    update.supportsUngrouping = false;
    update.hasVideo = !audioOnly;
    update.remoteHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:sid];
    update.localizedCallerName = title;

    self.callUUIDDict[callId] = uuid;
    [[WFAVEngineKit sharedEngineKit] registerCall:callId uuid:uuid];
    NSUUID *uu = [WFAVEngineKit sharedEngineKit].currentSession.callUUID;
    NSLog(@"the uuid is %@", uu.UUIDString);

    [self.provider reportNewIncomingCallWithUUID:uuid update:update completion:^(NSError * _Nullable error) {
        if(error) {
            NSLog(@"error:%@", error);
        }
    }];
}

#pragma - mark CXProviderDelegate
- (void)providerDidReset:(CXProvider *)provider {
    NSLog(@"providerDidReset");
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    NSLog(@"performStartCallAction");
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action {
    NSLog(@"performAnswerCallAction");
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionAllowBluetoothA2DP | AVAudioSessionCategoryOptionMixWithOthers error:nil];

    [action fulfill];
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    NSLog(@"performEndCallAction");
    NSUUID *uuid = [WFAVEngineKit sharedEngineKit].currentSession.callUUID;
    if([action.callUUID isEqual:uuid] || !uuid) {
        if ([WFAVEngineKit sharedEngineKit].currentSession.state != kWFAVEngineStateIdle) {
            [[WFAVEngineKit sharedEngineKit].currentSession endCall];
        }
    }
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action {
    if([action.callUUID isEqual:[WFAVEngineKit sharedEngineKit].currentSession.callUUID]) {
        if ([WFAVEngineKit sharedEngineKit].currentSession.state != kWFAVEngineStateIdle) {
            if (action.isMuted) {
                [[WFAVEngineKit sharedEngineKit].currentSession muteAudio:YES];
            } else {
                [[WFAVEngineKit sharedEngineKit].currentSession muteAudio:NO];
            }
        }
    }
    [action fulfill];
}

- (void)answerCall {
    [[WFAVEngineKit sharedEngineKit].currentSession answerCall:false callExtra:nil];
    [self.channel invokeMethod:@"showCallView" arguments:@{@"callSession":[RtckitPlugin callSession2Dict:[WFAVEngineKit sharedEngineKit].currentSession]}];
}

-(void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
    if ([WFAVEngineKit sharedEngineKit].currentSession.state == kWFAVEngineStateIncomming) {
        [self answerCall];
    } else {
        //有可能用户点击接听以后，IM服务消息还没有同步完成，来电消息还没有被处理，需要等待有来电session再接听.
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            int count = 60;
            while (count--) {
                [NSThread sleepForTimeInterval:0.05];
                if ([WFAVEngineKit sharedEngineKit].currentSession.state == kWFAVEngineStateIncomming) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self answerCall];
                    });
                    break;
                }
            }
            //3秒内没有接听成功，这里设置为失败
            [self.provider invalidate];
        });
    }
}
@end
