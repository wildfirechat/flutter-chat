#import "MomentclientPlugin.h"
#import <WFMomentClient/WFMClientJsonClient.h>

@interface MomentclientPlugin () <WFMomentJsonReceiveMessageDelegate>
@property(nonatomic, strong)FlutterMethodChannel* channel;
@end

@implementation MomentclientPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"momentclient"
                                     binaryMessenger:[registrar messenger]];
    MomentclientPlugin* instance = [[MomentclientPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    [WFMClientJsonClient sharedService].receiveMessageDelegate = instance;
    instance.channel = channel;
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

- (void)postFeed:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    int type = [dict[@"type"] intValue];
    NSString *text = dict[@"text"];
    NSMutableArray *medias = dict[@"medias"];
    NSArray<NSString *> *toUsers = dict[@"toUsers"];
    NSArray<NSString *> *excludeUsers = dict[@"excludeUsers"];
    NSArray<NSString *> *mentionedUsers = dict[@"mentionedUsers"];
    NSString *extra = dict[@"extra"];
    NSDictionary *feed = [[WFMClientJsonClient sharedService] postFeeds:type text:text medias:medias toUsers:toUsers excludeUsers:excludeUsers mentionedUsers:mentionedUsers extra:extra success:^(long long feedId, long long timestamp) {
        [self.channel invokeMethod:@"postFeedSuccess" arguments:@{@"requestId":@(requestId), @"feedId":@(feedId), @"timestamp":@(timestamp)}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
    result(feed);
}

- (void)deleteFeed:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    int64_t feedId = [dict[@"feedId"] longLongValue];
    [[WFMClientJsonClient sharedService] deleteFeed:feedId success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getFeeds:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    int64_t fromIndex = [dict[@"fromIndex"] longLongValue];
    int count = [dict[@"count"] intValue];
    NSString *user = dict[@"user"];
    
    [[WFMClientJsonClient sharedService] getFeeds:fromIndex count:count fromUser:user success:^(NSArray<NSDictionary *> * _Nonnull feeds) {
        [self.channel invokeMethod:@"getFeedsSuccess" arguments:@{@"requestId":@(requestId), @"feeds":feeds}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getFeed:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    int64_t feedId = [dict[@"feedId"] longLongValue];
    
    [[WFMClientJsonClient sharedService] getFeed:feedId success:^(NSDictionary * _Nonnull feed) {
        [self.channel invokeMethod:@"getFeedSuccess" arguments:@{@"requestId":@(requestId), @"feed":feed}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)postComment:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    int type = [dict[@"type"] intValue];
    int64_t feedId = [dict[@"feedId"] longLongValue];
    int64_t replyCommentId = [dict[@"replyCommentId"] longLongValue];
    NSString *text = dict[@"text"];
    NSString *replyTo = dict[@"replyTo"];
    NSString *extra = dict[@"extra"];
    
    NSDictionary *comment = [[WFMClientJsonClient sharedService] postComment:type feedId:feedId replyComment:replyCommentId text:text replyTo:replyTo extra:extra success:^(long long commentId, long long timestamp) {
        [self.channel invokeMethod:@"postCommentSuccess" arguments:@{@"requestId":@(requestId), @"commentId":@(commentId), @"timestamp":@(timestamp)}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
    
    result(comment);
}

- (void)deleteComment:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    int64_t feedId = [dict[@"feedId"] longLongValue];
    int64_t commentId = [dict[@"commentId"] longLongValue];
    
    [[WFMClientJsonClient sharedService] deleteComments:commentId feedId:feedId success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)getMessages:(NSDictionary *)dict result:(FlutterResult)result {
    int64_t fromIndex = [dict[@"fromIndex"] longLongValue];
    BOOL isNew = [dict[@"isNew"] boolValue];
    NSArray<NSDictionary *> *messages = [[WFMClientJsonClient sharedService] getMessages:fromIndex isNew:isNew];
    result(messages);
}

- (void)getUnreadCount:(NSDictionary *)dict result:(FlutterResult)result {
    int unreadCount = [[WFMClientJsonClient sharedService] getUnreadCount];
    result(@(unreadCount));
}

- (void)clearUnreadStatus:(NSDictionary *)dict result:(FlutterResult)result {
    [[WFMClientJsonClient sharedService] clearUnreadStatus];
    result(nil);
}

- (void)storeCache:(NSDictionary *)dict result:(FlutterResult)result {
    NSArray *feeds = dict[@"feeds"];
    NSString *userId = dict[@"userId"];
    [[WFMClientJsonClient sharedService] storeCache:feeds forUser:userId];
    result(nil);
}

- (void)restoreCache:(NSDictionary *)dict result:(FlutterResult)result {
    NSString *userId = dict[@"userId"];
    NSArray<NSDictionary *> *feeds = [[WFMClientJsonClient sharedService] restoreCache:userId];
    result(feeds);
}

- (void)getUserProfile:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    NSString *userId = dict[@"userId"];
    [[WFMClientJsonClient sharedService] getUserProfile:userId success:^(NSDictionary * _Nonnull profile) {
        [self.channel invokeMethod:@"getProfileSuccess" arguments:@{@"requestId":@(requestId), @"profile":profile}];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)updateMyProfile:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    int updateProfileType = [dict[@"updateProfileType"] intValue];
    NSString *strValue = dict[@"strValue"];
    int intValue = [dict[@"intValue"] intValue];
    
    [[WFMClientJsonClient sharedService] updateUserProfile:updateProfileType strValue:strValue intValue:intValue success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)updateBlackOrBlockList:(NSDictionary *)dict result:(FlutterResult)result {
    int requestId = [dict[@"requestId"] intValue];
    BOOL isBlock = [dict[@"isBlock"] boolValue];
    NSArray<NSString *> *addList = dict[@"addList"];
    NSArray<NSString *> *removeList = dict[@"removeList"];
    
    [[WFMClientJsonClient sharedService] updateBlackOrBlockList:isBlock addList:addList removeList:removeList success:^{
        [self callbackOperationVoidSuccess:requestId];
    } error:^(int error_code) {
        [self callbackOperationFailure:requestId errorCode:error_code];
    }];
}

- (void)updateLastReadTimestamp:(NSDictionary *)dict result:(FlutterResult)result {
    [[WFMClientJsonClient sharedService] updateLastReadTimestamp];
    result(nil);
}

- (void)getLastReadTimestamp:(NSDictionary *)dict result:(FlutterResult)result {
    int64_t timestamp = [[WFMClientJsonClient sharedService] getLastReadTimestamp];
    result(@(timestamp));
}

- (void)callbackOperationStringSuccess:(int)requestId strValue:(NSString *)strValue  {
    [self.channel invokeMethod:@"onOperationStringSuccess" arguments:@{@"requestId":@(requestId), @"string":strValue}];
}

- (void)callbackOperationVoidSuccess:(int)requestId {
    [self.channel invokeMethod:@"onOperationVoidSuccess" arguments:@{@"requestId":@(requestId)}];
}

- (void)callbackOperationFailure:(int)requestId errorCode:(int)errorCode {
    [self.channel invokeMethod:@"onOperationFailure" arguments:@{@"requestId":@(requestId), @"errorCode":@(errorCode)}];
}

- (void)getPlatformVersion:(NSDictionary *)dict result:(FlutterResult)result {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
}


#pragma - mark WFMomentJsonReceiveMessageDelegate
- (void)onReceiveNewComment:(NSDictionary *)commentContent {
    [self.channel invokeMethod:@"onReceiveNewComment" arguments:@{@"comment":commentContent}];
}

- (void)onReceiveMentionedFeed:(NSDictionary *)feedContent {
    [self.channel invokeMethod:@"onReceiveMentionedFeed" arguments:@{@"feed":feedContent}];
}
@end
