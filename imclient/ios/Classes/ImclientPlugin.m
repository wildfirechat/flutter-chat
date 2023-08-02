#import "ImclientPlugin.h"
#import <WFChatClient/WFCChatClient.h>

@interface ImclientPlugin ()
@property(nonatomic, strong)NSString *userId;
@property(nonatomic, strong)NSString *token;

@property(nonatomic, strong)FlutterMethodChannel* channel;
@end

ImclientPlugin *gIMClientInstance;

@implementation ImclientPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"imclient"
                                     binaryMessenger:[registrar messenger]];
    ImclientPlugin* instance = [[ImclientPlugin alloc] init];
    [instance observeIMEvents];
    [registrar addMethodCallDelegate:instance channel:channel];
    gIMClientInstance = instance;
    gIMClientInstance.channel = channel;
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
    [WFCCNetworkService sharedInstance].sendLogCommand = @"*#marslog#";
    [[WFCCIMService sharedWFCIMService] useRawMessage];
}

- (void)isLogined:(NSDictionary *)dict result:(FlutterResult)result {
    result(@([WFCCNetworkService sharedInstance].isLogined));
}

- (void)connect:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *host = dict[@"host"];
    NSString *userId = dict[@"userId"];
    NSString *token = dict[@"token"];
    [[WFCCNetworkService sharedInstance] setServerAddress:host];
    int64_t lastConnectTime = [[WFCCNetworkService sharedInstance] connect:userId token:token];
    result(@(lastConnectTime));
}

- (void)currentUserId:(NSDictionary *)dict result:(FlutterResult)result {
    result([WFCCNetworkService sharedInstance].userId);
}

- (void)connectionStatus:(NSDictionary *)dict result:(FlutterResult)result {
    result(@([WFCCNetworkService sharedInstance].currentConnectionStatus));
}

- (void)getClientId:(NSDictionary *)dict result:(FlutterResult)result {
    result([[WFCCNetworkService sharedInstance] getClientId]);
}

- (void)serverDeltaTime:(NSDictionary *)dict result:(FlutterResult)result {
    result(@([WFCCNetworkService sharedInstance].serverDeltaTime));
}

- (void)registerMessage:(NSDictionary *)dict result:(FlutterResult)result {
    int type = [dict[@"type"] intValue];
    int flag = [dict[@"flag"] intValue];
    [[WFCCIMService sharedWFCIMService] registerMessageFlag:type flag:flag];
}

- (void)disconnect:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL disablePush = [dict[@"disablePush"] boolValue];
    BOOL clearSession = [dict[@"clearSession"] boolValue];
    [[WFCCNetworkService sharedInstance] disconnect:disablePush clearSession:clearSession];
}

- (void)startLog:(NSDictionary *)dict result:(FlutterResult)result {
    [WFCCNetworkService startLog];
}

- (void)stopLog:(NSDictionary *)dict result:(FlutterResult)result {
    [WFCCNetworkService stopLog];
}

- (void)setSendLogCommand:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *cmd = dict[@"cmd"];
    [WFCCNetworkService sharedInstance].sendLogCommand = cmd;
}

- (void)useSM4:(NSDictionary *)dict result:(FlutterResult)result {
    [[WFCCNetworkService sharedInstance] useSM4];
}

- (void)setLiteMode:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL liteMode = [dict[@"liteMode"] boolValue];
    [[WFCCNetworkService sharedInstance] setLiteMode:liteMode];
}

- (void)setDeviceToken:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *deviceToken = dict[@"deviceToken"];
    [[WFCCNetworkService sharedInstance] setDeviceToken:deviceToken];
}

- (void)setVoipDeviceToken:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *voipToken = dict[@"voipToken"];
    [[WFCCNetworkService sharedInstance] setVoipDeviceToken:voipToken];
}

- (void)setBackupAddressStrategy:(NSDictionary *)dict result:(FlutterResult)result {
    int strategy = [dict[@"strategy"] intValue];
    [[WFCCNetworkService sharedInstance] setBackupAddressStrategy:strategy];
}

- (void)setBackupAddress:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *host = dict[@"host"];
    int port = [dict[@"port"] intValue];
    [[WFCCNetworkService sharedInstance] setBackupAddress:host port:port];
}

- (void)setProtoUserAgent:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *agent = dict[@"agent"];
    [[WFCCNetworkService sharedInstance] setProtoUserAgent:agent];
}

- (void)addHttpHeader:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *header = dict[@"header"];
    NSString *value = dict[@"value"];
    [[WFCCNetworkService sharedInstance] addHttpHeader:header value:value];
}

- (void)setProxyInfo:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *host = dict[@"host"];
    NSString *ip = dict[@"ip"];
    int port = [dict[@"port"] intValue];
    NSString *userName = dict[@"userName"];
    NSString *password = dict[@"password"];
    [[WFCCNetworkService sharedInstance] setProxyInfo:host ip:ip port:port username:userName password:password];
}

- (void)getProtoRevision:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *revision = [[WFCCNetworkService sharedInstance] getProtoRevision];
    result(revision);
}

- (void)getLogFilesPath:(NSDictionary *)dict result:(FlutterResult)result {
    result([WFCCNetworkService getLogFilesPath]);
}

- (void)getConversationInfos:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray *types = dict[@"types"];
    NSArray *lines = dict[@"lines"];
    NSArray<WFCCConversationInfo *> *infos = [[WFCCIMService sharedWFCIMService] getConversationInfos:types lines:lines];
    NSArray *output = [self convertModelList:infos];
    result(output);
}

- (void)getConversationInfo:(NSDictionary *)dict result:(FlutterResult)result {
    WFCCConversationInfo *info = [[WFCCIMService sharedWFCIMService] getConversationInfo:[self conversationFromDict:dict]];
    result([info toJsonObj]);
}

- (void)searchConversation:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray *types = dict[@"types"];
    NSArray *lines = dict[@"lines"];
    NSString *keyword = dict[@"keyword"];
    NSArray<WFCCConversationSearchInfo *> *searchInfos = [[WFCCIMService sharedWFCIMService] searchConversation:keyword inConversation:types lines:lines];
    result([self convertModelList:searchInfos]);
}

- (void)removeConversation:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *conversation = dict[@"conversation"];
    BOOL clearMessage = [dict[@"clearMessage"] boolValue];
    
    [[WFCCIMService sharedWFCIMService] removeConversation:[self conversationFromDict:conversation] clearMessage:clearMessage];
}

- (void)setConversationTop:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSDictionary *convDict = dict[@"conversation"];
    int top = [dict[@"top"] intValue];
    [[WFCCIMService sharedWFCIMService] setConversation:[self conversationFromDict:convDict] top:top success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)setConversationSilent:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSDictionary *convDict = dict[@"conversation"];
    BOOL isSilent = [dict[@"isSilent"] boolValue];
    [[WFCCIMService sharedWFCIMService] setConversation:[self conversationFromDict:convDict] silent:isSilent success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)setConversationDraft:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    NSString *draft = dict[@"draft"];
    [[WFCCIMService sharedWFCIMService] setConversation:[self conversationFromDict:convDict] draft:draft];
}

- (void)setConversationTimestamp:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    long long timestamp = [dict[@"timestamp"] longLongValue];
    [[WFCCIMService sharedWFCIMService] setConversation:[self conversationFromDict:convDict] timestamp:timestamp];
}

- (void)getFirstUnreadMessageId:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    
    long messageId = [[WFCCIMService sharedWFCIMService] getFirstUnreadMessageId:[self conversationFromDict:convDict]];
    result(@(messageId));
}

- (void)getConversationUnreadCount:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    
    WFCCUnreadCount *unreadCount = [[WFCCIMService sharedWFCIMService] getUnreadCount:[self conversationFromDict:convDict]];
    result([unreadCount toJsonObj]);
}

- (void)getConversationsUnreadCount:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray *types = dict[@"types"];
    NSArray *lines = dict[@"lines"];
    
    WFCCUnreadCount *unreadCount = [[WFCCIMService sharedWFCIMService] getUnreadCount:types lines:lines];
    result([unreadCount toJsonObj]);
}

- (void)clearConversationUnreadStatus:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    [[WFCCIMService sharedWFCIMService] clearUnreadStatus:[self conversationFromDict:convDict]];
    result(@(YES));
}

- (void)clearConversationsUnreadStatus:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray *types = dict[@"types"];
    NSArray *lines = dict[@"lines"];
    [[WFCCIMService sharedWFCIMService] clearUnreadStatus:types lines:lines];
    result(@(YES));
}

- (void)clearMessageUnreadStatusBefore:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    long messageId = [dict[@"messageId"] longValue];
    [[WFCCIMService sharedWFCIMService] clearMessageUnreadStatusBefore:messageId conversation:[self conversationFromDict:convDict]];
    result(@(YES));
}

- (void)clearMessageUnreadStatus:(NSDictionary *)dict result:(FlutterResult)result {
    long messageId = [dict[@"messageId"] longValue];
    [[WFCCIMService sharedWFCIMService] clearMessageUnreadStatus:messageId];
    result(@(YES));
}

- (void)markAsUnRead:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    BOOL sync = [dict[@"sync"] boolValue];
    WFCCConversation *conversation = [self conversationFromDict:convDict];
    BOOL ret = [[WFCCIMService sharedWFCIMService] markAsUnRead:conversation syncToOtherClient:sync];
    result(@(ret));
}


- (void)getConversationRead:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    NSMutableDictionary<NSString *, NSNumber *> *reads = [[WFCCIMService sharedWFCIMService] getConversationRead:[self conversationFromDict:convDict]];
    result(reads);
}

- (void)getMessageDelivery:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    NSMutableDictionary<NSString *, NSNumber *> *deliveries = [[WFCCIMService sharedWFCIMService] getMessageDelivery:[self conversationFromDict:convDict]];
    result(deliveries);
}

- (void)getMessages:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    NSArray<NSNumber *> *contentTypes = dict[@"contentTypes"];
    NSString *withUser = dict[@"withUser"];
    long long fromIndex = [dict[@"fromIndex"] longLongValue];
    int count = [dict[@"count"] intValue];
    
    [[WFCCIMService sharedWFCIMService] getMessagesV2:[self conversationFromDict:convDict] contentTypes:contentTypes from:fromIndex count:count withUser:withUser success:^(NSArray<WFCCMessage *> *messages) {
        result([self convertModelList:messages]);
    } error:^(int error_code) {
        result(@[]);
    }];
}

- (void)getMessagesByStatus:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    NSArray<NSNumber *> *messageStatus = dict[@"messageStatus"];
    NSString *withUser = dict[@"withUser"];
    long long fromIndex = [dict[@"fromIndex"] longLongValue];
    int count = [dict[@"count"] intValue];
    
    [[WFCCIMService sharedWFCIMService] getMessagesV2:[self conversationFromDict:convDict] messageStatus:messageStatus from:fromIndex count:count withUser:withUser success:^(NSArray<WFCCMessage *> *messages) {
        result([self convertModelList:messages]);
    } error:^(int error_code) {
        result(@[]);
    }];
    
}

- (void)getConversationsMessages:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray *types = dict[@"types"];
    NSArray *lines = dict[@"lines"];
    NSArray<NSNumber *> *contentTypes = dict[@"contentTypes"];
    NSString *withUser = dict[@"withUser"];
    long long fromIndex = [dict[@"fromIndex"] longLongValue];
    int count = [dict[@"count"] intValue];
    
    [[WFCCIMService sharedWFCIMService] getMessagesV2:types lines:lines contentTypes:contentTypes from:fromIndex count:count withUser:withUser success:^(NSArray<WFCCMessage *> *messages) {
        result([self convertModelList:messages]);
    } error:^(int error_code) {
        result(@[]);
    }];
}

- (void)getConversationsMessageByStatus:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray *types = dict[@"types"];
    NSArray *lines = dict[@"lines"];
    NSArray<NSNumber *> *messageStatus = dict[@"messageStatus"];
    NSString *withUser = dict[@"withUser"];
    long long fromIndex = [dict[@"fromIndex"] longLongValue];
    int count = [dict[@"count"] intValue];
    
    [[WFCCIMService sharedWFCIMService] getMessagesV2:types lines:lines messageStatus:messageStatus from:fromIndex count:count withUser:withUser success:^(NSArray<WFCCMessage *> *messages) {
        result([self convertModelList:messages]);
    } error:^(int error_code) {
        result(@[]);
    }];
}

- (void)getRemoteMessages:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    int requestId = [dict[@"requestId"] intValue];
    NSArray<NSNumber *> *contentTypes = dict[@"contentTypes"];
    long long beforeMessageUid = [dict[@"beforeMessageUid"] longLongValue];
    int count = [dict[@"count"] intValue];
    
    [[WFCCIMService sharedWFCIMService] getRemoteMessages:[self conversationFromDict:convDict] before:beforeMessageUid count:count contentTypes:contentTypes success:^(NSArray<WFCCMessage *> *messages) {
        [self.channel invokeMethod:@"onMessagesCallback" arguments:@{@"requestId":@(requestId), @"messages":[self convertModelList:messages]}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getRemoteMessage:(NSDictionary *)dict result:(FlutterResult)result {
    long long messageUid = [dict[@"messageUid"] longLongValue];
    int requestId = [dict[@"requestId"] intValue];

    [[WFCCIMService sharedWFCIMService] getRemoteMessage:messageUid success:^(WFCCMessage *message) {
        [self.channel invokeMethod:@"onMessageCallback" arguments:@{@"requestId":@(requestId), @"message":[message toJsonObj]}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getMessage:(NSDictionary *)dict result:(FlutterResult)result {
    long messageId = [dict[@"messageId"] longValue];
    
    WFCCMessage *msg = [[WFCCIMService sharedWFCIMService] getMessage:messageId];
    result([msg toJsonObj]);
}

- (void)getMessageByUid:(NSDictionary *)dict result:(FlutterResult)result {
    long long messageUid = [dict[@"messageUid"] longLongValue];
    
    WFCCMessage *msg = [[WFCCIMService sharedWFCIMService] getMessageByUid:messageUid];
    result([msg toJsonObj]);
}

- (void)searchMessages:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    NSString *keyword = dict[@"keyword"];
    BOOL order = [dict[@"order"] boolValue];
    int limit = [dict[@"limit"] intValue];
    int offset = [dict[@"offset"] intValue];
    NSString *withUser = dict[@"withUser"];
    
    
    NSArray<WFCCMessage *> *messages = [[WFCCIMService sharedWFCIMService] searchMessage:[self conversationFromDict:convDict] keyword:keyword order:order limit:limit offset:offset withUser:withUser];
    result([self convertModelList:messages]);
}

- (void)searchConversationsMessages:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray *conversationTypes = dict[@"types"];
    NSArray *lines = dict[@"lines"];
    NSString *keyword = dict[@"keyword"];
    NSArray<NSNumber *> *contentTypes = dict[@"contentTypes"];
    long long fromIndex = [dict[@"fromIndex"] intValue];
    int count = [dict[@"count"] intValue];
    NSString *withUser = dict[@"withUser"];
    
    NSArray<WFCCMessage *> *messages = [[WFCCIMService sharedWFCIMService] searchMessage:conversationTypes lines:lines contentTypes:contentTypes keyword:keyword from:fromIndex count:count withUser:withUser];
    result([self convertModelList:messages]);
}

- (void)sendMessage:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSDictionary *convDict = dict[@"conversation"];
    NSDictionary *contDict = dict[@"content"];
    NSArray<NSString *> *toUsers = dict[@"toUsers"];
    int expireDuration = [dict[@"expireDuration"] intValue];
    
    WFCCMessage *message = [[WFCCIMService sharedWFCIMService] send:[self conversationFromDict:convDict] content:[self contentFromDict:contDict] toUsers:toUsers expireDuration:expireDuration success:^(long long messageUid, long long timestamp) {
        [self.channel invokeMethod:@"onSendMessageSuccess" arguments:@{@"requestId":@(requestId), @"messageUid":@(messageUid), @"timestamp":@(timestamp)}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
    result([message toJsonObj]);
}

- (void)sendSavedMessage:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    long messageId = [dict[@"messageId"] longValue];
    int expireDuration = [dict[@"expireDuration"] intValue];
    
    WFCCMessage *msg = [[WFCCIMService sharedWFCIMService] getMessage:messageId];
    if(!msg) {
        [self callbackOperationFailure:requestId errorCode:-1];
        result(@(NO));
        return;
    }
    
    BOOL exist = [[WFCCIMService sharedWFCIMService] sendSavedMessage:msg expireDuration:expireDuration success:^(long long messageUid, long long timestamp) {
        [self.channel invokeMethod:@"onSendMessageSuccess" arguments:@{@"requestId":@(requestId), @"messageUid":@(messageUid), @"timestamp":@(timestamp)}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
    result(@(exist));
}

- (void)cancelSendingMessage:(NSDictionary *)dict result:(FlutterResult)result {
    int messageId = [dict[@"messageId"] intValue];
    
    BOOL ret = [[WFCCIMService sharedWFCIMService] cancelSendingMessage:messageId];
    result(@(ret));
}

- (void)recallMessage:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    long long messageUid = [dict[@"messageUid"] longLongValue];
    WFCCMessage *msg = [[WFCCIMService sharedWFCIMService] getMessageByUid:messageUid];
    if(!msg) {
        [self callbackOperationFailure:requestId errorCode:-1];
        result(@(NO));
        return;
    }
    
    [[WFCCIMService sharedWFCIMService] recall:msg success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)uploadMedia:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *fileName = dict[@"fileName"];
    int mediaType = [dict[@"mediaType"] intValue];
    FlutterStandardTypedData *binaryData = dict[@"mediaData"];
    NSData *mediaData = binaryData.data;
    
    [[WFCCIMService sharedWFCIMService] uploadMedia:fileName mediaData:mediaData mediaType:(WFCCMediaType)mediaType success:^(NSString *remoteUrl) {
        [self.channel invokeMethod:@"onSendMediaMessageUploaded" arguments:@{@"requestId":@(requestId), @"remoteUrl":remoteUrl}];
    } progress:^(long uploaded, long total) {
        [self.channel invokeMethod:@"onSendMediaMessageProgress" arguments:@{@"requestId":@(requestId), @"uploaded":@(uploaded), @"total":@(total)}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getMediaUploadUrl:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *fileName = dict[@"fileName"];
    int mediaType = [dict[@"mediaType"] intValue];
    NSString *contentType = dict[@"contentType"];
    
    [[WFCCIMService sharedWFCIMService] getUploadUrl:fileName mediaType:(WFCCMediaType)mediaType contentType:contentType success:^(NSString *uploadUrl, NSString *downloadUrl, NSString *backupUploadUrl, int type) {
        [self.channel invokeMethod:@"onGetUploadUrl" arguments:@{@"requestId":@(requestId), @"uploadUrl":uploadUrl, @"downloadUrl":downloadUrl, @"backupUploadUrl":backupUploadUrl, @"type":@(type)}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)deleteMessage:(NSDictionary *)dict result:(FlutterResult)result {
    long messageId = [dict[@"messageId"] longValue];
    BOOL ret = [[WFCCIMService sharedWFCIMService] deleteMessage:messageId];
    result(@(ret));
}

- (void)batchDeleteMessages:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray<NSNumber *> *messageUids = dict[@"messageUids"];
    BOOL ret = [[WFCCIMService sharedWFCIMService] batchDeleteMessages:messageUids];
    result(@(ret));
}

- (void)deleteRemoteMessage:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    long messageUid = [dict[@"messageUid"] longLongValue];
    [[WFCCIMService sharedWFCIMService] deleteRemoteMessage:messageUid success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
    
}

- (void)clearMessages:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];
    long long beforeTime = [dict[@"before"] longLongValue];
    if(beforeTime > 0) {
        [[WFCCIMService sharedWFCIMService] clearMessages:[self conversationFromDict:convDict] before:beforeTime];
    } else {
        [[WFCCIMService sharedWFCIMService] clearMessages:[self conversationFromDict:convDict]];
    }
}

- (void)clearRemoteConversationMessage:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSDictionary *convDict = dict[@"conversation"];
    WFCCConversation *conversation = [self conversationFromDict:convDict];
    [[WFCCIMService sharedWFCIMService] clearRemoteConversationMessage:conversation success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)setMediaMessagePlayed:(NSDictionary *)dict result:(FlutterResult)result {
    long messageId = [dict[@"messageId"] longValue];
    [[WFCCIMService sharedWFCIMService] setMediaMessagePlayed:messageId];
}

- (void)setMessageLocalExtra:(NSDictionary *)dict result:(FlutterResult)result {
    long messageId = [dict[@"messageId"] longValue];
    NSString *localExtra = dict[@"localExtra"];
    [[WFCCIMService sharedWFCIMService] setMessage:messageId localExtra:localExtra];
}

- (void)insertMessage:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *conversation = dict[@"conversation"];
    NSDictionary *content = dict[@"content"];
    int status = [dict[@"status"] intValue];
    long long serverTime = [dict[@"serverTime"] longLongValue];
    NSArray<NSString *> *toUsers = dict[@"toUsers"];

    WFCCMessage *msg = [[WFCCIMService sharedWFCIMService] insert:[self conversationFromDict:conversation] sender:self.userId content:[self contentFromDict:content] status:(WFCCMessageStatus)status notify:NO toUsers:toUsers serverTime:serverTime];
    result(@(msg.messageId));
}

- (void)updateMessage:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *content = dict[@"content"];
    long messageId = [((NSString*) dict[@"messageId"]) longLongValue];

    [[WFCCIMService sharedWFCIMService] updateMessage:messageId content:[self contentFromDict:content]];
}

- (void)updateRemoteMessageContent:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSDictionary *content = dict[@"content"];
    WFCCMessageContent *msgContent = [self contentFromDict:content];
    long long messageUid = [dict[@"messageUid"] longLongValue];
    BOOL distribute = [dict[@"distribute"] boolValue];
    BOOL updateLocal = [dict[@"updateLocal"] boolValue];
    

    [[WFCCIMService sharedWFCIMService] updateRemoteMessage:messageUid content:msgContent distribute:distribute updateLocal:updateLocal success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)updateMessageStatus:(NSDictionary *)dict result:(FlutterResult)result {
    int status = [dict[@"status"] intValue];
    long messageId = [((NSString*) dict[@"messageId"]) longLongValue];

    [[WFCCIMService sharedWFCIMService] updateMessage:messageId status:(WFCCMessageStatus)status];
}

- (void)getMessageCount:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary *convDict = dict[@"conversation"];

    int count = [[WFCCIMService sharedWFCIMService] getMessageCount:[self conversationFromDict:convDict]];
    result(@(count));
}

- (void)getUserInfo:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    BOOL refresh = [dict[@"refresh"] boolValue];
    NSString *groupId = dict[@"groupId"];

    WFCCUserInfo *userInfo = [[WFCCIMService sharedWFCIMService] getUserInfo:userId inGroup:groupId refresh:refresh];
    result([userInfo toJsonObj]);
}

- (void)getUserInfos:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray<NSString *> *userIds = dict[@"userIds"];
    NSString *groupId = dict[@"groupId"];

    NSArray<WFCCUserInfo *> *userInfos = [[WFCCIMService sharedWFCIMService] getUserInfos:userIds inGroup:groupId];
    result([self convertModelList:userInfos]);
}

- (void)searchUser:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *keyword = dict[@"keyword"];
    int searchType = [dict[@"searchType"] intValue];
    int page = [dict[@"page"] intValue];
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] searchUser:keyword searchType:(WFCCSearchUserType)searchType page:page success:^(NSArray<WFCCUserInfo *> *machedUsers) {
        [self.channel invokeMethod:@"onSearchUserResult" arguments:@{@"requestId":@(requestId), @"users":[self convertModelList:machedUsers]}];
    } error:^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }];
}

- (void)getUserInfoAsync:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *userId = dict[@"userId"];
    BOOL refresh = [dict[@"refresh"] boolValue];
    
    [[WFCCIMService sharedWFCIMService] getUserInfo:userId refresh:refresh success:^(WFCCUserInfo *userInfo) {
        [self.channel invokeMethod:@"getUserInfoAsyncCallback" arguments:@{@"requestId":@(requestId), @"user":[userInfo toJsonObj]}];
    } error:^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }];
}

- (void)isMyFriend:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    
    BOOL ret = [[WFCCIMService sharedWFCIMService] isMyFriend:userId];
    result(@(ret));
}

- (void)getMyFriendList:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL refresh = [dict[@"refresh"] boolValue];
    
    NSArray<NSString *> *friendIds = [[WFCCIMService sharedWFCIMService] getMyFriendList:refresh];
    result(friendIds);
}

- (void)searchFriends:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *keyword = dict[@"keyword"];
    
    NSArray<WFCCUserInfo *> *friendInfos = [[WFCCIMService sharedWFCIMService] searchFriends:keyword];
    result([self convertModelList:friendInfos]);
}

- (void)getFriends:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL refresh = [dict[@"refresh"] boolValue];
    
    NSArray<WFCCFriend *> *friends = [[WFCCIMService sharedWFCIMService] getFriendList:refresh];
    result([self convertModelList:friends]);
}

- (void)searchGroups:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *keyword = dict[@"keyword"];
    
    NSArray<WFCCGroupSearchInfo *> *searchGroupInfos = [[WFCCIMService sharedWFCIMService] searchGroups:keyword];
    result([self convertModelList:searchGroupInfos]);
}

- (void)getIncommingFriendRequest:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray<WFCCFriendRequest *> *requests = [[WFCCIMService sharedWFCIMService] getIncommingFriendRequest];
    result([self convertModelList:requests]);
}

- (void)getOutgoingFriendRequest:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray<WFCCFriendRequest *> *requests = [[WFCCIMService sharedWFCIMService] getOutgoingFriendRequest];
    result([self convertModelList:requests]);
}

- (void)getFriendRequest:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    int direction = [dict[@"direction"] intValue];

    WFCCFriendRequest *request = [[WFCCIMService sharedWFCIMService] getFriendRequest:userId direction:direction];
    result([request toJsonObj]);
}

- (void)loadFriendRequestFromRemote:(NSDictionary *)dict result:(FlutterResult)result {
    [[WFCCIMService sharedWFCIMService] loadFriendRequestFromRemote];
}

- (void)getUnreadFriendRequestStatus:(NSDictionary *)dict result:(FlutterResult)result {
    int ret = [[WFCCIMService sharedWFCIMService] getUnreadFriendRequestStatus];
    result(@(ret));
}

- (void)clearUnreadFriendRequestStatus:(NSDictionary *)dict result:(FlutterResult)result {
    [[WFCCIMService sharedWFCIMService] clearUnreadFriendRequestStatus];
}

- (void)deleteFriend:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] deleteFriend:userId success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)sendFriendRequest:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    NSString *reason = dict[@"reason"];
    NSString *extra = dict[@"extra"];
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] sendFriendRequest:userId reason:reason extra:extra success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)handleFriendRequest:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    NSString *extra = dict[@"extra"];
    int requestId = [dict[@"requestId"] intValue];
    bool accept = [dict[@"accept"] boolValue];
    
    [[WFCCIMService sharedWFCIMService] handleFriendRequest:userId accept:accept extra:extra success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getFriendAlias:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *friendId = dict[@"friendId"];
    
    NSString *alias = [[WFCCIMService sharedWFCIMService] getFriendAlias:friendId];
    result(alias);
}

- (void)setFriendAlias:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *friendId = dict[@"friendId"];
    NSString *alias = dict[@"alias"];
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] setFriend:friendId alias:alias success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getFriendExtra:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *friendId = dict[@"friendId"];
    
    NSString *extra = [[WFCCIMService sharedWFCIMService] getFriendExtra:friendId];
    result(extra);
}

- (void)isBlackListed:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    
    BOOL ret = [[WFCCIMService sharedWFCIMService] isBlackListed:userId];
    result(@(ret));
}

- (void)getBlackList:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL refresh = [dict[@"refresh"] boolValue];
    
    NSArray<NSString *> *blackList = [[WFCCIMService sharedWFCIMService] getBlackList:refresh];
    result(blackList);
}

- (void)setBlackList:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    BOOL isBlackListed = [dict[@"isBlackListed"] boolValue];
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] setBlackList:userId isBlackListed:isBlackListed success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getGroupMembers:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *groupId = dict[@"groupId"];
    BOOL refresh = [dict[@"refresh"] boolValue];
    
    NSArray<WFCCGroupMember *> *members = [[WFCCIMService sharedWFCIMService] getGroupMembers:groupId forceUpdate:refresh];
    result([self convertModelList:members]);
}

- (void)getGroupMembersByCount:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *groupId = dict[@"groupId"];
    int count = [dict[@"count"] intValue];

    NSArray<WFCCGroupMember *> *members = [[WFCCIMService sharedWFCIMService] getGroupMembers:groupId count:count];
    result([self convertModelList:members]);
}

- (void)getGroupMembersByTypes:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *groupId = dict[@"groupId"];
    int memberType = [dict[@"memberType"] intValue];
    
    NSArray<WFCCGroupMember *> *members = [[WFCCIMService sharedWFCIMService] getGroupMembers:groupId type:(WFCCGroupMemberType)memberType];
    result([self convertModelList:members]);
}

- (void)getGroupMembersAsync:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *groupId = dict[@"groupId"];
    int requestId = [dict[@"requestId"] intValue];
    BOOL refresh = [dict[@"refresh"] boolValue];
    
    [[WFCCIMService sharedWFCIMService] getGroupMembers:groupId refresh:refresh success:^(NSString *groupId, NSArray<WFCCGroupMember *> *memberList) {
        [self.channel invokeMethod:@"getGroupMembersAsyncCallback" arguments:@{@"requestId":@(requestId), @"members":[self convertModelList:memberList], @"groupId":groupId}];
    } error:^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }];
}

- (void)getGroupInfo:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *groupId = dict[@"groupId"];
    BOOL refresh = [dict[@"refresh"] boolValue];
    
    WFCCGroupInfo *groupInfo = [[WFCCIMService sharedWFCIMService] getGroupInfo:groupId refresh:refresh];
    result([groupInfo toJsonObj]);
}

- (void)getGroupInfoAsync:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *groupId = dict[@"groupId"];
    int requestId = [dict[@"requestId"] intValue];
    BOOL refresh = [dict[@"refresh"] boolValue];
    
    [[WFCCIMService sharedWFCIMService] getGroupInfo:groupId refresh:refresh success:^(WFCCGroupInfo *groupInfo) {
        [self.channel invokeMethod:@"getGroupInfoAsyncCallback" arguments:@{@"requestId":@(requestId), @"groupInfo":[groupInfo toJsonObj]}];
    } error:^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }];
}

- (void)getGroupMember:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *groupId = dict[@"groupId"];
    NSString *memberId = dict[@"memberId"];
    
    WFCCGroupMember *member = [[WFCCIMService sharedWFCIMService] getGroupMember:groupId memberId:memberId];
    result([member toJsonObj]);
}

- (void)createGroup:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    NSString *groupName = dict[@"groupName"];
    NSString *groupExtra = dict[@"groupExtra"];
    NSString *groupPortrait = dict[@"groupPortrait"];
    int groupType = [dict[@"type"] intValue];
    NSArray *groupMembers = dict[@"groupMembers"];
    NSString *memberExtra = dict[@"memberExtra"];
    NSArray *notifyLines = dict[@"notifyLines"];
    NSDictionary *notifyContent = dict[@"notifyContent"];
    
    [[WFCCIMService sharedWFCIMService] createGroup:groupId name:groupName portrait:groupPortrait type:(WFCCGroupType)groupType groupExtra:groupExtra members:groupMembers memberExtra:memberExtra notifyLines:notifyLines notifyContent:[self contentFromDict:notifyContent] success:^(NSString *groupId) {
        [self callbackOperationStringSuccess:requestId strValue:groupId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)addGroupMembers:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    NSArray *members = dict[@"groupMembers"];
    NSString *memberExtra = dict[@"memberExtra"];
    NSArray *notifyLines = dict[@"notifyLines"];
    NSDictionary *notifyContent = dict[@"notifyContent"];
    
    [[WFCCIMService sharedWFCIMService] addMembers:members toGroup:groupId memberExtra:memberExtra notifyLines:notifyLines notifyContent:[self contentFromDict:notifyContent] success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)kickoffGroupMembers:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    NSArray *members = dict[@"groupMembers"];
    NSArray *notifyLines = dict[@"notifyLines"];
    NSDictionary *notifyContent = dict[@"notifyContent"];
    [[WFCCIMService sharedWFCIMService] kickoffMembers:members fromGroup:groupId notifyLines:notifyLines notifyContent:[self contentFromDict:notifyContent] success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)quitGroup:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    NSArray *notifyLines = dict[@"notifyLines"];
    NSDictionary *notifyContent = dict[@"notifyContent"];
    
    [[WFCCIMService sharedWFCIMService] quitGroup:groupId notifyLines:notifyLines notifyContent:[self contentFromDict:notifyContent] success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)dismissGroup:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    NSArray *notifyLines = dict[@"notifyLines"];
    NSDictionary *notifyContent = dict[@"notifyContent"];
    
    [[WFCCIMService sharedWFCIMService] dismissGroup:groupId notifyLines:notifyLines notifyContent:[self contentFromDict:notifyContent] success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)modifyGroupInfo:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    int modifyType = [dict[@"modifyType"] intValue];
    NSString *newValue = dict[@"value"];
    NSArray *notifyLines = dict[@"notifyLines"];
    NSDictionary *notifyContent = dict[@"notifyContent"];
    
    [[WFCCIMService sharedWFCIMService] modifyGroupInfo:groupId type:(ModifyGroupInfoType)modifyType newValue:newValue notifyLines:notifyLines notifyContent:[self contentFromDict:notifyContent] success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)modifyGroupAlias:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    NSString *newAlias = dict[@"newAlias"];
    NSArray *notifyLines = dict[@"notifyLines"];
    NSDictionary *notifyContent = dict[@"notifyContent"];
    
    [[WFCCIMService sharedWFCIMService] modifyGroupAlias:groupId alias:newAlias notifyLines:notifyLines notifyContent:[self contentFromDict:notifyContent] success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)modifyGroupMemberAlias:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    NSString *memberId = dict[@"memberId"];
    NSString *newAlias = dict[@"newAlias"];
    NSArray *notifyLines = dict[@"notifyLines"];
    NSDictionary *notifyContent = dict[@"notifyContent"];
    
    [[WFCCIMService sharedWFCIMService] modifyGroupMemberAlias:groupId memberId:memberId alias:newAlias notifyLines:notifyLines notifyContent:[self contentFromDict:notifyContent] success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)transferGroup:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    NSString *newOwner = dict[@"newOwner"];
    NSArray *notifyLines = dict[@"notifyLines"];
    NSDictionary *notifyContent = dict[@"notifyContent"];
    
    [[WFCCIMService sharedWFCIMService] transferGroup:groupId to:newOwner notifyLines:notifyLines notifyContent:[self contentFromDict:notifyContent] success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)setGroupManager:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    BOOL isSet = [dict[@"isSet"] boolValue];
    NSArray *memberIds = dict[@"memberIds"];
    NSArray *notifyLines = dict[@"notifyLines"];
    NSDictionary *notifyContent = dict[@"notifyContent"];
    
    [[WFCCIMService sharedWFCIMService] setGroupManager:groupId isSet:isSet memberIds:memberIds notifyLines:notifyLines notifyContent:[self contentFromDict:notifyContent] success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)muteGroupMember:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    BOOL isSet = [dict[@"isSet"] boolValue];
    NSArray *memberIds = dict[@"memberIds"];
    NSArray *notifyLines = dict[@"notifyLines"];
    NSDictionary *notifyContent = dict[@"notifyContent"];
    
    [[WFCCIMService sharedWFCIMService] muteGroupMember:groupId isSet:isSet memberIds:memberIds notifyLines:notifyLines notifyContent:[self contentFromDict:notifyContent] success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)allowGroupMember:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    BOOL isSet = [dict[@"isSet"] boolValue];
    NSArray *memberIds = dict[@"memberIds"];
    NSArray *notifyLines = dict[@"notifyLines"];
    NSDictionary *notifyContent = dict[@"notifyContent"];
    
    [[WFCCIMService sharedWFCIMService] allowGroupMember:groupId isSet:isSet memberIds:memberIds notifyLines:notifyLines notifyContent:[self contentFromDict:notifyContent] success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getGroupRemark:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *groupId = dict[@"groupId"];
    NSString *remark = [[WFCCIMService sharedWFCIMService] getGroupRemark:groupId];
    result(remark);
}

- (void)setGroupRemark:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    NSString *remark = dict[@"remark"];
    [[WFCCIMService sharedWFCIMService] setGroup:groupId remark:remark success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}


- (void)getFavGroups:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray *gids = [[WFCCIMService sharedWFCIMService] getFavGroups];
    result(gids);
}

- (void)isFavGroup:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *groupId = dict[@"groupId"];
    BOOL ret = [[WFCCIMService sharedWFCIMService] isFavGroup:groupId];
    result(@(ret));
}

- (void)setFavGroup:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *groupId = dict[@"groupId"];
    BOOL isFav = [dict[@"isFav"] boolValue];
    
    [[WFCCIMService sharedWFCIMService] setFavGroup:groupId fav:isFav success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }];
}

- (void)getUserSetting:(NSDictionary *)dict result:(FlutterResult)result {
    int scope = [dict[@"scope"] intValue];
    NSString *key = dict[@"key"];
    
    NSString *setting = [[WFCCIMService sharedWFCIMService] getUserSetting:(UserSettingScope)scope key:key];
    result(setting);
}

- (void)getUserSettings:(NSDictionary *)dict result:(FlutterResult)result {
    int scope = [dict[@"scope"] intValue];
    
    NSDictionary<NSString *, NSString *> *settings = [[WFCCIMService sharedWFCIMService] getUserSettings:(UserSettingScope)scope];
    result(settings);
}

- (void)setUserSetting:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *key = dict[@"key"];
    NSString *value = dict[@"value"];
    int scope = [dict[@"scope"] intValue];
    
    [[WFCCIMService sharedWFCIMService] setUserSetting:(UserSettingScope)scope key:key value:value success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)modifyMyInfo:(NSDictionary *)dict result:(FlutterResult)result {
    NSDictionary<NSNumber *, NSString *> *values = dict[@"values"];
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] modifyMyInfo:values success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)isGlobalSilent:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL ret = [[WFCCIMService sharedWFCIMService] isGlobalSilent];
    result(@(ret));
}

- (void)setGlobalSilent:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    bool isSilent = [dict[@"isSilent"] boolValue];
    
    [[WFCCIMService sharedWFCIMService] setGlobalSilent:isSilent success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)isVoipNotificationSilent:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL ret = [[WFCCIMService sharedWFCIMService] isVoipNotificationSilent];
    result(@(ret));
}

- (void)setVoipNotificationSilent:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    bool isSilent = [dict[@"isSilent"] boolValue];
    
    [[WFCCIMService sharedWFCIMService] setVoipNotificationSilent:isSilent success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)isEnableSyncDraft:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL ret = [[WFCCIMService sharedWFCIMService] isEnableSyncDraft];
    result(@(ret));
}

- (void)setEnableSyncDraft:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    bool enable = [dict[@"enable"] boolValue];
    
    [[WFCCIMService sharedWFCIMService] setEnableSyncDraft:enable success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getNoDisturbingTimes:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    [[WFCCIMService sharedWFCIMService] getNoDisturbingTimes:^(int startMins, int endMins) {
        [self.channel invokeMethod:@"onOperationIntPairSuccess" arguments:@{@"requestId":@(requestId), @"first":@(startMins), @"second":@(endMins)}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:-1];
    }];
}

- (void)setNoDisturbingTimes:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    int startMins = [dict[@"startMins"] intValue];
    int endMins = [dict[@"endMins"] intValue];
    [[WFCCIMService sharedWFCIMService] setNoDisturbingTimes:startMins endMins:endMins success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)clearNoDisturbingTimes:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] clearNoDisturbingTimes:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)isNoDisturbing:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL ret = [[WFCCIMService sharedWFCIMService] isNoDisturbing];
    result(@(ret));
}

- (void)isHiddenNotificationDetail:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL ret = [[WFCCIMService sharedWFCIMService] isHiddenNotificationDetail];
    result(@(ret));
}

- (void)setHiddenNotificationDetail:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    bool isHidden = [dict[@"isHidden"] boolValue];
    [[WFCCIMService sharedWFCIMService] setHiddenNotificationDetail:isHidden success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)isHiddenGroupMemberName:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *groupId = dict[@"groupId"];
    BOOL ret = [[WFCCIMService sharedWFCIMService] isHiddenGroupMemberName:groupId];
    result(@(ret));
}

- (void)setHiddenGroupMemberName:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *groupId = dict[@"groupId"];
    bool isHidden = [dict[@"isHidden"] boolValue];
    int requestId = [dict[@"requestId"] intValue];
    [[WFCCIMService sharedWFCIMService] setHiddenGroupMemberName:isHidden group:groupId success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getMyGroups:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] getMyGroups:^(NSArray<NSString *> *groupIds) {
        [self.channel invokeMethod:@"onOperationStringListSuccess" arguments:@{@"requestId":@(requestId), @"strings":groupIds}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getCommonGroups:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] getCommonGroups:userId success:^(NSArray<NSString *> *groupIds) {
        [self.channel invokeMethod:@"onOperationStringListSuccess" arguments:@{@"requestId":@(requestId), @"strings":groupIds}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)isUserEnableReceipt:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL ret = [[WFCCIMService sharedWFCIMService] isUserEnableReceipt];
    result(@(ret));
}


- (void)setUserEnableReceipt:(NSDictionary *)dict result:(FlutterResult)result {
    bool isEnable = [dict[@"isEnable"] boolValue];
    int requestId = [dict[@"requestId"] intValue];
    [[WFCCIMService sharedWFCIMService] setUserEnableReceipt:isEnable success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getFavUsers:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray *favUsers = [[WFCCIMService sharedWFCIMService] getFavUsers];
    result(favUsers);
}

- (void)isFavUser:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    BOOL ret = [[WFCCIMService sharedWFCIMService] isFavUser:userId];
    result(@(ret));
}

- (void)setFavUser:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    BOOL isFav = [dict[@"isFav"] boolValue];
    int requestId = [dict[@"requestId"] intValue];
    [[WFCCIMService sharedWFCIMService] setFavUser:userId fav:isFav success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }];
}

- (void)joinChatroom:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *chatroomId = dict[@"chatroomId"];
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] joinChatroom:chatroomId success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }];
}

- (void)quitChatroom:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *chatroomId = dict[@"chatroomId"];
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] quitChatroom:chatroomId success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }];
}

- (void)getChatroomInfo:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *chatroomId = dict[@"chatroomId"];
    int requestId = [dict[@"requestId"] intValue];
    long long updateDt = [dict[@"updateDt"] longLongValue];
    
    [[WFCCIMService sharedWFCIMService] getChatroomInfo:chatroomId upateDt:updateDt success:^(WFCCChatroomInfo *chatroomInfo) {
        [self.channel invokeMethod:@"onGetChatroomInfoResult" arguments:@{@"requestId":@(requestId), @"chatroomInfo":[chatroomInfo toJsonObj]}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getChatroomMemberInfo:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *chatroomId = dict[@"chatroomId"];
    int requestId = [dict[@"requestId"] intValue];
    int maxCount = [dict[@"maxCount"] intValue];
    
    [[WFCCIMService sharedWFCIMService] getChatroomMemberInfo:chatroomId maxCount:maxCount success:^(WFCCChatroomMemberInfo *memberInfo) {
        [self.channel invokeMethod:@"onGetChatroomMemberInfoResult" arguments:@{@"requestId":@(requestId), @"chatroomMemberInfo":[memberInfo toJsonObj]}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)createChannel:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *channelName = dict[@"channelName"];
    NSString *channelPortrait = dict[@"channelPortrait"];
    NSString *desc = dict[@"desc"];
    NSString *extra = dict[@"extra"];
    int status = [dict[@"status"] intValue];
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] createChannel:channelName portrait:channelPortrait desc:desc extra:extra success:^(WFCCChannelInfo *channelInfo) {
        [self.channel invokeMethod:@"onCreateChannelSuccess" arguments:@{@"requestId":@(requestId), @"channelInfo":[channelInfo toJsonObj]}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getChannelInfo:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *channelId = dict[@"channelId"];
    BOOL refresh = [dict[@"refresh"] boolValue];
    
    WFCCChannelInfo *channelInfo = [[WFCCIMService sharedWFCIMService] getChannelInfo:channelId refresh:refresh];
    result([channelInfo toJsonObj]);
}

- (void)modifyChannelInfo:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *channelId = dict[@"channelId"];
    int type = [dict[@"type"] intValue];
    NSString *newValue = dict[@"newValue"];
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] modifyChannelInfo:channelId type:(ModifyChannelInfoType)type newValue:newValue success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)searchChannel:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *keyword = dict[@"keyword"];
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] searchChannel:keyword success:^(NSArray<WFCCChannelInfo *> *machedChannels) {
        [self.channel invokeMethod:@"onSearchChannelResult" arguments:@{@"requestId":@(requestId), @"channelInfos":[self convertModelList:machedChannels]}];
    } error:^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }];
}

- (void)isListenedChannel:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *channelId = dict[@"channelId"];
    
    BOOL ret = [[WFCCIMService sharedWFCIMService] isListenedChannel:channelId];
    result(@(ret));
}

- (void)listenChannel:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *channelId = dict[@"channelId"];
    BOOL listen = [dict[@"listen"] boolValue];
    int requestId = [dict[@"requestId"] intValue];
    [[WFCCIMService sharedWFCIMService] listenChannel:channelId listen:listen success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }];
}

- (void)getListenedChannels:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray *channels = [[WFCCIMService sharedWFCIMService] getListenedChannels];
    result(channels);
}

- (void)destroyChannel:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *channelId = dict[@"channelId"];
    int requestId = [dict[@"requestId"] intValue];
    [[WFCCIMService sharedWFCIMService] destoryChannel:channelId success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getOnlineInfos:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray<WFCCPCOnlineInfo *> *infos = [[WFCCIMService sharedWFCIMService] getPCOnlineInfos];
    result([self convertModelList:infos]);
}

- (void)kickoffPCClient:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *pcClientId = dict[@"clientId"];
    int requestId = [dict[@"requestId"] intValue];
    
    [[WFCCIMService sharedWFCIMService] kickoffPCClient:pcClientId success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)isMuteNotificationWhenPcOnline:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL ret = [[WFCCIMService sharedWFCIMService] isMuteNotificationWhenPcOnline];
    result(@(ret));
}

- (void)muteNotificationWhenPcOnline:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL isMute = [dict[@"isMute"] boolValue];
    int requestId = [dict[@"requestId"] intValue];
    [[WFCCIMService sharedWFCIMService] muteNotificationWhenPcOnline:isMute success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getConversationFiles:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    NSDictionary *convDict = dict[@"conversation"];
    int requestId = [dict[@"requestId"] intValue];
    int order = [dict[@"order"] intValue];
    long long beforeMessageUid = [dict[@"beforeMessageUid"] longLongValue];
    int count = [dict[@"count"] intValue];
    
    [[WFCCIMService sharedWFCIMService] getConversationFiles:[self conversationFromDict:convDict] fromUser:userId beforeMessageUid:beforeMessageUid order:(WFCCFileRecordOrder)order count:count success:^(NSArray<WFCCFileRecord *> *files) {
        [self.channel invokeMethod:@"onFilesResult" arguments:@{@"requestId":@(requestId), @"files":[self convertModelList:files]}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getMyFiles:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    int order = [dict[@"order"] intValue];
    long long beforeMessageUid = [dict[@"beforeMessageUid"] longLongValue];
    int count = [dict[@"count"] intValue];
    
    [[WFCCIMService sharedWFCIMService] getMyFiles:beforeMessageUid order:(WFCCFileRecordOrder)order count:count success:^(NSArray<WFCCFileRecord *> *files) {
        [self.channel invokeMethod:@"onFilesResult" arguments:@{@"requestId":@(requestId), @"files":[self convertModelList:files]}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)deleteFileRecord:(NSDictionary *)dict result:(FlutterResult)result {
    long long messageUid = [dict[@"messageUid"] longLongValue];
    int requestId = [dict[@"requestId"] intValue];
    [[WFCCIMService sharedWFCIMService] deleteFileRecord:messageUid success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)searchFiles:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *keyword = dict[@"keyword"];
    NSString *userId = dict[@"userId"];
    int order = [dict[@"order"] intValue];
    NSDictionary *convDict = dict[@"conversation"];
    int requestId = [dict[@"requestId"] intValue];
    long long beforeMessageUid = [dict[@"beforeMessageUid"] longLongValue];
    int count = [dict[@"count"] intValue];
    
    [[WFCCIMService sharedWFCIMService] searchFiles:keyword conversation:[self conversationFromDict:convDict] fromUser:userId beforeMessageUid:beforeMessageUid order:(WFCCFileRecordOrder)order count:count success:^(NSArray<WFCCFileRecord *> *files) {
        [self.channel invokeMethod:@"onFilesResult" arguments:@{@"requestId":@(requestId), @"files":[self convertModelList:files]}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)searchMyFiles:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *keyword = dict[@"keyword"];
    int requestId = [dict[@"requestId"] intValue];
    int order = [dict[@"order"] intValue];
    long long beforeMessageUid = [dict[@"beforeMessageUid"] longLongValue];
    int count = [dict[@"count"] intValue];
    
    [[WFCCIMService sharedWFCIMService] searchMyFiles:keyword beforeMessageUid:beforeMessageUid order:(WFCCFileRecordOrder)order count:count success:^(NSArray<WFCCFileRecord *> *files) {
        [self.channel invokeMethod:@"onFilesResult" arguments:@{@"requestId":@(requestId), @"files":[self convertModelList:files]}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getAuthorizedMediaUrl:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *mediaPath = dict[@"mediaPath"];
    int requestId = [dict[@"requestId"] intValue];
    long long messageUid = [dict[@"messageUid"] longLongValue];
    int mediaType = [dict[@"mediaType"] intValue];
    
    [[WFCCIMService sharedWFCIMService] getAuthorizedMediaUrl:messageUid mediaType:(WFCCMediaType)mediaType mediaPath:mediaPath success:^(NSString *authorizedUrl, NSString *backupAuthorizedUrl) {
        [self callbackOperationStringSuccess:requestId strValue:authorizedUrl];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getAuthCode:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *applicationId = dict[@"applicationId"];
    int type = [dict[@"type"] intValue];
    NSString *host = dict[@"host"];
    
    [[WFCCIMService sharedWFCIMService] getAuthCode:applicationId type:type host:host success:^(NSString *authCode) {
        [self callbackOperationStringSuccess:requestId strValue:authCode];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}


- (void)configApplication:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *applicationId = dict[@"applicationId"];
    int type = [dict[@"type"] intValue];
    long long timestamp = [dict[@"timestamp"] intValue];
    NSString *nonce = dict[@"nonce"];
    NSString *signature = dict[@"signature"];
    
    [[WFCCIMService sharedWFCIMService] configApplication:applicationId type:type timestamp:timestamp nonce:nonce signature:signature success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}


- (void)getWavData:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *amrPath = dict[@"amrPath"];

    NSData *data = [[WFCCIMService sharedWFCIMService] getWavData:amrPath];;
    result([FlutterStandardTypedData typedDataWithBytes:data]);
}

- (void)beginTransaction:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL ret = [[WFCCIMService sharedWFCIMService] beginTransaction];
    result(@(ret));
}

- (void)commitTransaction:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL ret = [[WFCCIMService sharedWFCIMService] commitTransaction];
    result(@(ret));
}

- (void)isCommercialServer:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL ret = [[WFCCIMService sharedWFCIMService] isCommercialServer];
    result(@(ret));
}

- (void)isReceiptEnabled:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL ret = [[WFCCIMService sharedWFCIMService] isReceiptEnabled];
    result(@(ret));
}

- (void)isGlobalDisableSyncDraft:(NSDictionary *)dict result:(FlutterResult)result {
    BOOL ret = [[WFCCIMService sharedWFCIMService] isGlobalDisableSyncDraft];
    result(@(ret));
}

- (void)getUserOnlineState:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    WFCCUserOnlineState *userOnline = [[WFCCIMService sharedWFCIMService] getUserOnlineState:userId];
    result([userOnline toJsonObj]);
}

- (void)getMyCustomState:(NSDictionary *)dict result:(FlutterResult)result {
    WFCCUserCustomState *customState = [[WFCCIMService sharedWFCIMService] getMyCustomState];
    result([customState toJsonObj]);
}

- (void)setMyCustomState:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    int customState = [dict[@"customState"] intValue];
    NSString *customText = dict[@"customText"];
    WFCCUserCustomState *state = [[WFCCUserCustomState alloc] init];
    state.state = customState;
    state.text = customText;
    [[WFCCIMService sharedWFCIMService] setMyCustomState:state success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)watchOnlineState:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    int conversationType = [dict[@"conversationType"] intValue];
    NSArray<NSString *> *targets = dict[@"targets"];
    int watchDuration = [dict[@"watchDuration"] intValue];
    
    [[WFCCIMService sharedWFCIMService] watchOnlineState:conversationType targets:targets duration:watchDuration success:^(NSArray<WFCCUserOnlineState *> *states) {
        [self.channel invokeMethod:@"onWatchOnlineStateSuccess" arguments:@{@"requestId":@(requestId), @"states":[self convertModelList:states]}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)unwatchOnlineState:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    int conversationType = [dict[@"conversationType"] intValue];
    NSArray<NSString *> *targets = dict[@"targets"];
    
    [[WFCCIMService sharedWFCIMService] unwatchOnlineState:conversationType targets:targets success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)isEnableUserOnlineState:(NSDictionary *)dict result:(FlutterResult)result {
    WFCCUserCustomState *customState = [[WFCCIMService sharedWFCIMService] getMyCustomState];
    result(@([[WFCCIMService sharedWFCIMService] isEnableUserOnlineState]));
}

+ (void)setDeviceToken:(NSString *)deviceToken {
    [[WFCCNetworkService sharedInstance] setDeviceToken:deviceToken];
}

#pragma mark - tools
- (void)callbackOperationStringSuccess:(int)requestId strValue:(NSString *)strValue  {
    [self.channel invokeMethod:@"onOperationStringSuccess" arguments:@{@"requestId":@(requestId), @"string":strValue}];
}

- (void)callbackOperationVoidSuccess:(int)requestId {
    [self.channel invokeMethod:@"onOperationVoidSuccess" arguments:@{@"requestId":@(requestId)}];
}

- (void)callbackOperationFailure:(int)requestId errorCode:(int)errorCode {
    [self.channel invokeMethod:@"onOperationFailure" arguments:@{@"requestId":@(requestId), @"errorCode":@(errorCode)}];
}

- (NSArray<NSDictionary *> *)convertModelList:(NSArray<WFCCJsonSerializer *> *)models {
    __block NSMutableArray *arr = [[NSMutableArray alloc] init];
    [models enumerateObjectsUsingBlock:^(WFCCJsonSerializer *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [arr addObject:[obj toJsonObj]];
    }];
    return arr;
}

- (WFCCConversation *)conversationFromDict:(NSDictionary *)conversation {
    int type = [conversation[@"type"] intValue];
    NSString *target = conversation[@"target"];
    int line = [conversation[@"line"] intValue];
    return [WFCCConversation conversationWithType:(WFCCConversationType)type target:target line:line];
}

- (WFCCMessagePayload *)payloadFromDict:(NSDictionary *)payload {
    WFCCMediaMessagePayload *content = [[WFCCMediaMessagePayload alloc] init];
    
    content.contentType = [payload[@"type"] intValue];
    content.searchableContent = payload[@"searchableContent"];
    content.pushContent = payload[@"pushContent"];
    content.pushData = payload[@"pushData"];
    content.content = payload[@"content"];

    FlutterStandardTypedData *binaryData = payload[@"binaryContent"];
    if (binaryData) {
        content.binaryContent = binaryData.data;
    }

    content.localContent = payload[@"localContent"];
    content.mediaType = (WFCCMediaType)[payload[@"mediaType"] intValue];
    content.remoteMediaUrl = payload[@"remoteMediaUrl"];
    content.localMediaPath = payload[@"localMediaPath"];
    content.mentionedType = [payload[@"mentionedtype"] intValue];
    content.mentionedTargets = payload[@"mentionedTargets"];
    content.extra = payload[@"extra"];
    return content;
}

- (WFCCMessageContent *)contentFromDict:(NSDictionary *)content {
    WFCCMessagePayload *payload = [self payloadFromDict:content];
    WFCCMessageContent *cnt = [WFCCRawMessageContent contentOfPayload:payload];
    cnt.extra = payload.extra;
    return cnt;
}

#pragma mark - delegates
- (void)observeIMEvents {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onRecallMessage:) name:kRecallMessages object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDeleteMessage:) name:kDeleteMessages object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onReceiveMessage:) name:kReceiveMessages object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMessageReaded:) name:kMessageReaded object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMessageDelivered:) name:kMessageDelivered object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onUserOnlineStateUpdated:) name:kUserOnlineStateUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSecretChatStateChanged:) name:kSecretChatStateUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSecretMessageStartBurning:) name:kSecretMessageStartBurning object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSecretMessageBurned:) name:kSecretMessageBurned object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onConnectionStatusChanged:) name:kConnectionStatusChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onGroupInfoUpdated:) name:kGroupInfoUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onGroupMemberUpdated:) name:kGroupMemberUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onChannelInfoUpdated:) name:kChannelInfoUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onUserInfoUpdated:) name:kUserInfoUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFriendListUpdated:) name:kFriendListUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFriendRequestUpdated:) name:kFriendRequestUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSettingUpdated:) name:kSettingUpdated object:nil];
}
- (void)onRecallMessage:(NSNotification *)notification {
    long long messageUid = [notification.object longLongValue];
    [self.channel invokeMethod:@"onRecallMessage" arguments:@{@"messageUid":@(messageUid)}];
}

- (void)onDeleteMessage:(NSNotification *)notification {
    long long messageUid = [notification.object longLongValue];
    [self.channel invokeMethod:@"onDeleteMessage" arguments:@{@"messageUid":@(messageUid)}];
}

- (void)onReceiveMessage:(NSNotification *)notification {
    NSMutableArray<WFCCMessage *> *messages = notification.object;
    BOOL hasMore = [notification.userInfo[@"hasMore"] boolValue];
    [self.channel invokeMethod:@"onReceiveMessage" arguments:@{@"messages":[self convertModelList:messages], @"hasMore":@(hasMore)}];
}

- (void)onMessageReaded:(NSNotification *)notification {
    NSArray<WFCCReadReport *> *readeds = notification.object;
    [self.channel invokeMethod:@"onMessageReaded" arguments:@{@"readeds":[self convertModelList:readeds]}];
}

- (void)onMessageDelivered:(NSNotification *)notification {
    NSArray<WFCCDeliveryReport *> *delivereds = notification.object;
    [self.channel invokeMethod:@"onMessageDelivered" arguments:@{@"delivereds":[self convertModelList:delivereds]}];
}

- (void)onConferenceEvent:(NSString *)event {
    
}

- (void)onUserOnlineStateUpdated:(NSNotification *)notification {
    NSArray<WFCCUserOnlineState *> *events = notification.userInfo[@"states"];
    [self.channel invokeMethod:@"onUserOnlineEvent" arguments:@{@"states":[self convertModelList:events]}];
}

- (void)onSecretChatStateChanged:(NSNotification *)notification {
    NSString *target = notification.object;
    int state = [notification.userInfo[@"state"] intValue];
    [self.channel invokeMethod:@"onSecretChatStateChanged" arguments:@{@"target":target, @"state":@(state)}];
}

- (void)onSecretMessageStartBurning:(NSNotification *)notification {
    NSString *targetId = notification.object;
    long messageId = [notification.userInfo[@"messageId"] longValue];
    [self.channel invokeMethod:@"onSecretMessageStartBurning" arguments:@{@"target":targetId, @"messageId":@(messageId)}];
}

- (void)onSecretMessageBurned:(NSNotification *)notification {
    NSString *targetId = notification.object;
    NSArray<NSNumber *> *messageIds = notification.userInfo[@"messageIds"];
    [self.channel invokeMethod:@"onSecretMessageBurned" arguments:@{@"target":targetId, @"messageIds":messageIds}];
}

- (void)onConnectionStatusChanged:(NSNotification *)notification {
    int status = [notification.object intValue];
    [self.channel invokeMethod:@"onConnectionStatusChanged" arguments:@(status)];
}

- (void)onUserInfoUpdated:(NSNotification *)notification {
    NSArray<WFCCUserInfo *> *updatedUserInfo = notification.userInfo[@"userInfoList"];
    [self.channel invokeMethod:@"onUserInfoUpdated" arguments:@{@"users":[self convertModelList:updatedUserInfo]}];
}

- (void)onGroupInfoUpdated:(NSNotification *)notification {
    NSArray<WFCCGroupInfo *> *updatedGroupInfo = notification.userInfo[@"groupInfoList"];
    [self.channel invokeMethod:@"onGroupInfoUpdated" arguments:@{@"groups":[self convertModelList:updatedGroupInfo]}];
}

- (void)onFriendListUpdated:(NSNotification *)notification {
    NSArray<NSString *> *friendIds = notification.object;
    [self.channel invokeMethod:@"onFriendListUpdated" arguments:@{@"friends":friendIds}];
}

- (void)onFriendRequestUpdated:(NSNotification *)notification {
    NSArray<NSString *> *newFriendRequests = notification.object;
    [self.channel invokeMethod:@"onFriendRequestUpdated" arguments:@{@"requests":newFriendRequests}];
}

- (void)onSettingUpdated:(NSNotification *)notification {
    [self.channel invokeMethod:@"onSettingUpdated" arguments:nil];
}

- (void)onChannelInfoUpdated:(NSNotification *)notification {
    NSArray<WFCCChannelInfo *> *updatedChannelInfo = notification.userInfo[@"channelInfoList"];
    [self.channel invokeMethod:@"onChannelInfoUpdated" arguments:@{@"channels":[self convertModelList:updatedChannelInfo]}];
}

- (void)onGroupMemberUpdated:(NSNotification *)notification {
    NSString *groupId = notification.object;
    NSArray<WFCCGroupMember *> *updatedGroupMembers = notification.userInfo[@"members"];
    [self.channel invokeMethod:@"onGroupMemberUpdated" arguments:@{@"groupId":groupId, @"members":[self convertModelList:updatedGroupMembers]}];
}
@end
