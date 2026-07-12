//
//  WFCCallKitManager.h
//  Runner
//
//  CallKit integration for incoming VOIP calls.
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>
#import <CallKit/CallKit.h>
#import <PushKit/PushKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WFCCallKitManager : NSObject <CXProviderDelegate, PKPushRegistryDelegate>

- (instancetype)initWithMethodChannel:(FlutterMethodChannel *)channel;

/// Register for PushKit VoIP push notifications.
- (void)registerVoipPush;

/// Report a new incoming call to the system CallKit UI.
- (void)reportIncomingCallWithCallId:(NSString *)callId
                            callerId:(NSString *)callerId
                          callerName:(NSString *)callerName
                           audioOnly:(BOOL)audioOnly;

/// Mark a call as connected from the app side.
- (void)reportCallConnected:(NSString *)callId;

/// Mark a call as ended from the app side.
- (void)reportCallEnded:(NSString *)callId;

@end

NS_ASSUME_NONNULL_END
