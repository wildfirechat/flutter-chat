#import "FlutterImclientPlugin.h"
#import <UIKit/UIKit.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import <sys/xattr.h>
#import <CommonCrypto/CommonDigest.h>
#import "app_callback.h"
#include <mars/baseevent/base_logic.h>
#include <mars/xlog/xlogger.h>
#include <mars/xlog/xloggerbase.h>
#include <mars/xlog/appender.h>
#include <mars/proto/proto.h>
#include <mars/stn/stn_logic.h>
#include <list>
#import "WFCCNetworkStatus.h"
#import <mars/proto/MessageDB.h>


#ifdef __cplusplus
extern "C" {
#endif
extern int decode_amr(const char* infile, NSMutableData *outData);
#ifdef __cplusplus
}
#endif
/**
 连接状态

 - kConnectionStatusSecretKeyMismatch 密钥错误
 - kConnectionStatusTokenIncorrect Token错误
 - kConnectionStatusServerDown 服务器关闭
 - kConnectionStatusRejected: 被拒绝
 - kConnectionStatusLogout: 退出登录
 - kConnectionStatusUnconnected: 未连接
 - kConnectionStatusConnecting: 连接中
 - kConnectionStatusConnected: 已连接
 - kConnectionStatusReceiving: 获取离线消息中，可忽略
 */
typedef NS_ENUM(NSInteger, ConnectionStatus) {
  kConnectionStatusSecretKeyMismatch = -6,
  kConnectionStatusTokenIncorrect = -5,
  kConnectionStatusServerDown = -4,
  kConnectionStatusRejected = -3,
  kConnectionStatusLogout = -2,
  kConnectionStatusUnconnected = -1,
  kConnectionStatusConnecting = 0,
  kConnectionStatusConnected = 1,
  kConnectionStatusReceiving = 2
};


@protocol RefreshGroupInfoDelegate <NSObject>
- (void)onGroupInfoUpdated:(NSMutableArray<NSMutableDictionary *> *)updatedGroupInfos;
@end

@protocol RefreshGroupMemberDelegate <NSObject>
- (void)onGroupMemberUpdated:(NSString *)groupId members:(NSMutableArray<NSMutableDictionary *> *)updatedGroupMembers;
@end

@protocol RefreshChannelInfoDelegate <NSObject>
- (void)onChannelInfoUpdated:(NSMutableArray<NSMutableDictionary *> *)updatedChannelInfos;
@end

@protocol RefreshUserInfoDelegate <NSObject>
- (void)onUserInfoUpdated:(NSMutableArray<NSMutableDictionary *> *)updatedUserInfos;
@end

@protocol RefreshFriendListDelegate <NSObject>
- (void)onFriendListUpdated:(NSMutableArray<NSString *> *)friendList;
@end

@protocol RefreshFriendRequestDelegate <NSObject>
- (void)onFriendRequestsUpdated:(NSMutableArray<NSString *> *)newFriendRequests;
@end

@protocol RefreshSettingDelegate <NSObject>
- (void)onSettingUpdated;
@end

@protocol ConnectionStatusDelegate <NSObject>
- (void)onConnectionStatusChanged:(ConnectionStatus)status;
@end

@protocol ReceiveMessageDelegate <NSObject>
- (void)onReceiveMessage:(NSMutableArray<NSMutableDictionary *> *)messages hasMore:(BOOL)hasMore;
- (void)onRecallMessage:(long long)messageUid;
- (void)onDeleteMessage:(long long)messageUid;
- (void)onMessageDelivered:(NSMutableDictionary *)delivereds;
- (void)onMessageReaded:(NSMutableArray<NSMutableDictionary *> *)readeds;
@end

@protocol ConferenceEventDelegate <NSObject>
- (void)onConferenceEvent:(NSString *)event;
@end

class CSCB : public mars::stn::ConnectionStatusCallback {
public:
  CSCB(id<ConnectionStatusDelegate> delegate) : m_delegate(delegate) {
  }
  void onConnectionStatusChanged(mars::stn::ConnectionStatus connectionStatus) {
    if (m_delegate) {
      [m_delegate onConnectionStatusChanged:(ConnectionStatus)connectionStatus];
    }
  }
  id<ConnectionStatusDelegate> m_delegate;
};

static NSMutableDictionary *convertProtoMessageContent(const mars::stn::TMessageContent &content) {
    NSMutableDictionary *payload = [[NSMutableDictionary alloc] init];
    [payload setValue:@(content.type) forKey:@"type"];
    if (!content.searchableContent.empty())
        [payload setValue:[NSString stringWithUTF8String:content.searchableContent.c_str()] forKey:@"searchableContent"];
    if (!content.pushContent.empty())
        [payload setValue:[NSString stringWithUTF8String:content.pushContent.c_str()] forKey:@"pushContent"];
    if (!content.pushData.empty())
        [payload setValue:[NSString stringWithUTF8String:content.pushData.c_str()] forKey:@"pushData"];
    if (!content.content.empty())
        [payload setValue:[NSString stringWithUTF8String:content.content.c_str()] forKey:@"content"];
    if (!content.binaryContent.empty())
        [payload setValue:[FlutterStandardTypedData typedDataWithBytes:[NSData dataWithBytes:content.binaryContent.c_str() length:content.binaryContent.length()]] forKey:@"binaryContent"];
    if (!content.localContent.empty())
        [payload setValue:[NSString stringWithUTF8String:content.localContent.c_str()] forKey:@"localContent"];
    if (content.mediaType > 0)
        [payload setValue:@(content.mediaType) forKey:@"mediaType"];
    if (!content.remoteMediaUrl.empty())
        [payload setValue:[NSString stringWithUTF8String:content.remoteMediaUrl.c_str()] forKey:@"remoteMediaUrl"];
    if (!content.localMediaPath.empty())
        [payload setValue:[NSString stringWithUTF8String:content.localMediaPath.c_str()] forKey:@"localMediaPath"];
    if (content.mentionedType > 0)
        [payload setValue:@(content.mentionedType) forKey:@"mentionedType"];
    
    if (!content.mentionedTargets.empty()) {
        NSMutableArray *mentionedTargets = [[NSMutableArray alloc] init];
        for (std::list<std::string>::const_iterator it = content.mentionedTargets.begin(); it != content.mentionedTargets.end(); it++) {
            [mentionedTargets addObject:[NSString stringWithUTF8String:(*it).c_str()]];
        }
        [payload setValue:mentionedTargets forKey:@"mentionedTargets"];
    }
    if (!content.extra.empty())
        [payload setValue:[NSString stringWithUTF8String:content.extra.c_str()] forKey:@"extra"];
    
    return  payload;
}

static NSMutableDictionary *convertProtoMessage(const mars::stn::TMessage *tMessage) {
    if (tMessage->target.empty()) {
        return nil;
    }
    NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
    if (!tMessage->from.empty()) {
        [ret setValue:[NSString stringWithUTF8String:tMessage->from.c_str()] forKey:@"fromUser"];
    }
    NSMutableDictionary *conv = [[NSMutableDictionary alloc] init];
    [conv setValue:@(tMessage->conversationType) forKey:@"type"];
    [conv setValue:[NSString stringWithUTF8String:tMessage->target.c_str()] forKey:@"target"];
    if (tMessage->line > 0)
        [conv setValue:@(tMessage->line) forKey:@"line"];
    [ret setValue:conv forKey:@"conversation"];
    if(tMessage->messageId)
        [ret setValue:@(tMessage->messageId) forKey:@"messageId"];
    if(tMessage->messageUid)
        [ret setValue:@(tMessage->messageUid) forKey:@"messageUid"];
    if(tMessage->timestamp)
        [ret setValue:@(tMessage->timestamp) forKey:@"timestamp"];
    if (!tMessage->to.empty()) {
        NSMutableArray *toUsers = [[NSMutableArray alloc] init];
        for (std::list<std::string>::const_iterator it = tMessage->to.begin(); it != tMessage->to.end(); ++it) {
            NSString *user = [NSString stringWithUTF8String:(*it).c_str()];
            [toUsers addObject:user];
        }
        [ret setValue:toUsers forKey:@"toUsers"];
    }
    [ret setValue:@(tMessage->direction) forKey:@"direction"];
    [ret setValue:@(tMessage->status) forKey:@"status"];
    [ret setValue:convertProtoMessageContent(tMessage->content) forKey:@"content"];
    return ret;
}

NSMutableArray* convertProtoMessageList(const std::list<mars::stn::TMessage> &messageList, BOOL reverse) {
    NSMutableArray *messages = [[NSMutableArray alloc] init];
    for (std::list<mars::stn::TMessage>::const_iterator it = messageList.begin(); it != messageList.end(); it++) {
        const mars::stn::TMessage &tmsg = *it;
        NSMutableDictionary *msg = convertProtoMessage(&tmsg);
        if (msg) {
            if (reverse) {
                [messages insertObject:msg atIndex:0];
            } else {
                [messages addObject:msg];
            }
        }
    }
    return messages;
}

static NSMutableDictionary *convertProtoReadEntry(const mars::stn::TReadEntry &entry) {
    NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *conv = [[NSMutableDictionary alloc] init];
    conv[@"type"] = @(entry.conversationType);
    conv[@"target"] = [NSString stringWithUTF8String:entry.target.c_str()];
    conv[@"line"] = @(entry.line);
    
    ret[@"conversation"] = conv;
    ret[@"userId"] = [NSString stringWithUTF8String:entry.userId.c_str()];
    ret[@"readDt"] = @(entry.readDt);
    return ret;
}

NSMutableArray* convertProtoReadEntryList(const std::list<mars::stn::TReadEntry> &readEntryList) {
    NSMutableArray *messages = [[NSMutableArray alloc] init];
    for (std::list<mars::stn::TReadEntry>::const_iterator it = readEntryList.begin(); it != readEntryList.end(); it++) {
        [messages addObject:convertProtoReadEntry(*it)];
    }
    return messages;
}

NSMutableDictionary* convertProtoUserReceivedList(const std::map<std::string, int64_t> &userReceived) {
    NSMutableDictionary *messages = [[NSMutableDictionary alloc] init];
    for (std::map<std::string, int64_t>::const_iterator it = userReceived.begin(); it != userReceived.end(); it++) {
        messages[[NSString stringWithUTF8String:it->first.c_str()]] = @(it->second);
    }
    return messages;
}

NSMutableDictionary *convertProtoUserInfo(const mars::stn::TUserInfo &tui) {
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    userInfo[@"userId"] = [NSString stringWithUTF8String:tui.uid.c_str()];
    userInfo[@"name"] = [NSString stringWithUTF8String:tui.name.c_str()];
    if (!tui.portrait.empty())
        userInfo[@"portrait"] = [NSString stringWithUTF8String:tui.portrait.c_str()];
    
    if (tui.deleted) {
        userInfo[@"deleted"] = @(tui.deleted);
        userInfo[@"displayName"] = @"已删除用户";
    } else {
        if(!tui.displayName.empty())
            userInfo[@"displayName"] = [NSString stringWithUTF8String:tui.displayName.c_str()];
        userInfo[@"gender"] = @(tui.gender);
        if(!tui.social.empty())
            userInfo[@"social"] = [NSString stringWithUTF8String:tui.social.c_str()];
        if(!tui.mobile.empty())
            userInfo[@"mobile"] = [NSString stringWithUTF8String:tui.mobile.c_str()];
        if(!tui.email.empty())
            userInfo[@"email"] = [NSString stringWithUTF8String:tui.email.c_str()];
        if(!tui.address.empty())
            userInfo[@"address"] = [NSString stringWithUTF8String:tui.address.c_str()];
        if(!tui.company.empty())
            userInfo[@"company"] = [NSString stringWithUTF8String:tui.company.c_str()];
        if(!tui.social.empty())
            userInfo[@"social"] = [NSString stringWithUTF8String:tui.social.c_str()];
    }
    if(!tui.friendAlias.empty())
        userInfo[@"friendAlias"] = [NSString stringWithUTF8String:tui.friendAlias.c_str()];
    if(!tui.groupAlias.empty())
        userInfo[@"groupAlias"] = [NSString stringWithUTF8String:tui.groupAlias.c_str()];
    if(!tui.extra.empty())
        userInfo[@"extra"] = [NSString stringWithUTF8String:tui.extra.c_str()];
    if(tui.updateDt)
        userInfo[@"updateDt"] = @(tui.updateDt);
    if(tui.type)
        userInfo[@"type"] = @(tui.type);
    
    return userInfo;
}

NSMutableArray<NSMutableDictionary *>* converProtoUserInfos(const std::list<mars::stn::TUserInfo> &userInfoList) {
    NSMutableArray *out = [[NSMutableArray alloc] init];
    for (std::list<mars::stn::TUserInfo>::const_iterator it = userInfoList.begin(); it != userInfoList.end(); it++) {
        [out addObject:convertProtoUserInfo(*it)];
    }
    return out;
}

NSMutableDictionary *convertProtoGroupInfo(const mars::stn::TGroupInfo &tgi) {
    NSMutableDictionary *groupInfo = [[NSMutableDictionary alloc] init];
    groupInfo[@"type"] = @(tgi.type);
    groupInfo[@"target"] = [NSString stringWithUTF8String:tgi.target.c_str()];
    if(!tgi.name.empty())
        groupInfo[@"name"] = [NSString stringWithUTF8String:tgi.name.c_str()];
    if(!tgi.extra.empty())
        groupInfo[@"extra"] = [NSString stringWithUTF8String:tgi.extra.c_str()];;
    if(!tgi.portrait.empty())
        groupInfo[@"portrait"] = [NSString stringWithUTF8String:tgi.portrait.c_str()];
    if(!tgi.owner.empty())
        groupInfo[@"owner"] = [NSString stringWithUTF8String:tgi.owner.c_str()];
    if(tgi.memberCount)
        groupInfo[@"memberCount"] = @(tgi.memberCount);
    if(tgi.mute)
        groupInfo[@"mute"] = @(tgi.mute);
    if(tgi.joinType)
        groupInfo[@"joinType"] = @(tgi.joinType);
    if(tgi.searchable)
        groupInfo[@"privateChat"] = @(tgi.privateChat);
    if(tgi.searchable)
        groupInfo[@"searchable"] = @(tgi.searchable);
    if(tgi.historyMessage)
        groupInfo[@"historyMessage"] = @(tgi.historyMessage);
    if(tgi.maxMemberCount)
        groupInfo[@"maxMemberCount"] = @(tgi.maxMemberCount);
    if(tgi.updateDt)
        groupInfo[@"updateDt"] = @(tgi.updateDt);
    return groupInfo;
}

NSMutableArray<NSMutableDictionary *> *convertProtoGroupInfos(const std::list<mars::stn::TGroupInfo> &tgis) {
    NSMutableArray *ret = [[NSMutableArray alloc] init];
    for (std::list<mars::stn::TGroupInfo>::const_iterator it = tgis.begin(); it != tgis.end(); it++) {
        [ret addObject:convertProtoGroupInfo(*it)];
    }
    return ret;
}

NSMutableDictionary *convertProtoGroupMember(const mars::stn::TGroupMember &tgi) {
    NSMutableDictionary *member = [[NSMutableDictionary alloc] init];
    member[@"groupId"] = [NSString stringWithUTF8String:tgi.groupId.c_str()];
    member[@"memberId"] = [NSString stringWithUTF8String:tgi.memberId.c_str()];
    if(!tgi.alias.empty())
        member[@"alias"] = [NSString stringWithUTF8String:tgi.alias.c_str()];;
    if(tgi.type)
        member[@"type"] = @(tgi.type);
    if(tgi.updateDt)
        member[@"updateDt"] = @(tgi.updateDt);
    if(tgi.createDt)
        member[@"createDt"] = @(tgi.createDt);
    return member;
}

NSMutableArray<NSMutableDictionary *> *convertProtoGroupMembers(const std::list<mars::stn::TGroupMember> &tgis) {
    NSMutableArray *ret = [[NSMutableArray alloc] init];
    for (std::list<mars::stn::TGroupMember>::const_iterator it = tgis.begin(); it != tgis.end(); it++) {
        [ret addObject:convertProtoGroupMember(*it)];
    }
    return ret;
}

NSMutableDictionary *convertProtoGroupSearchResult(const mars::stn::TGroupSearchResult &tgsr) {
    NSMutableDictionary *searchGroupInfo = [[NSMutableDictionary alloc] init];
    searchGroupInfo[@"groupInfo"] = convertProtoGroupInfo(tgsr.groupInfo);
    searchGroupInfo[@"marchType"] = @(tgsr.marchedType);
    if (!tgsr.marchedMemberNames.empty()) {
        NSMutableArray *members = [[NSMutableArray alloc] init];
        for (std::string name : tgsr.marchedMemberNames) {
            [members addObject:[NSString stringWithUTF8String:name.c_str()]];
        }
        searchGroupInfo[@"marchedMemberNames"] = [members copy];
    }
    
    return searchGroupInfo;
}

NSMutableDictionary *convertProtoChannelInfo(const mars::stn::TChannelInfo &tci) {
    if (tci.channelId.empty()) {
        return nil;
    }
    NSMutableDictionary *channelInfo = [[NSMutableDictionary alloc] init];
    channelInfo[@"channelId"] = [NSString stringWithUTF8String:tci.channelId.c_str()];
    if(!tci.desc.empty())
        channelInfo[@"desc"] = [NSString stringWithUTF8String:tci.desc.c_str()];
    if(!tci.name.empty())
        channelInfo[@"name"] = [NSString stringWithUTF8String:tci.name.c_str()];
    if(!tci.extra.empty())
        channelInfo[@"extra"] = [NSString stringWithUTF8String:tci.extra.c_str()];
    if(!tci.portrait.empty())
        channelInfo[@"portrait"] = [NSString stringWithUTF8String:tci.portrait.c_str()];
    if(!tci.owner.empty())
        channelInfo[@"owner"] = [NSString stringWithUTF8String:tci.owner.c_str()];
    if(!tci.secret.empty())
        channelInfo[@"secret"] = [NSString stringWithUTF8String:tci.secret.c_str()];
    if(!tci.callback.empty())
        channelInfo[@"callback"] = [NSString stringWithUTF8String:tci.callback.c_str()];
    if(tci.status)
        channelInfo[@"status"] = @(tci.status);
    if(tci.updateDt)
        channelInfo[@"updateDt"] = @(tci.updateDt);
    return channelInfo;
}

NSMutableArray<NSMutableDictionary *> *convertProtoChannelInfoList(const std::list<mars::stn::TChannelInfo> &tcis) {
    NSMutableArray *ret = [[NSMutableArray alloc] init];
    for (std::list<mars::stn::TChannelInfo>::const_iterator it = tcis.begin(); it != tcis.end(); it++) {
        [ret addObject:convertProtoChannelInfo(*it)];
    }
    return ret;
}

static NSMutableDictionary *convertProtoUnreadCount(const mars::stn::TUnreadCount &tUnreadCount) {
    NSMutableDictionary *unread = [[NSMutableDictionary alloc] init];
    unread[@"unread"] = @(tUnreadCount.unread);
    if(tUnreadCount.unreadMention)
        unread[@"unreadMention"] = @(tUnreadCount.unreadMention);
    if(tUnreadCount.unreadMentionAll)
        unread[@"unreadMentionAll"] = @(tUnreadCount.unreadMentionAll);
    return unread;
}

static NSMutableDictionary* convertProtoConversationInfo(const mars::stn::TConversation &tConv) {
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *conversation = [[NSMutableDictionary alloc] init];
    conversation[@"type"] = @(tConv.conversationType);
    conversation[@"target"] = [NSString stringWithUTF8String:tConv.target.c_str()];
    conversation[@"line"] = @(tConv.line);
    info[@"conversation"] = conversation;
    NSMutableDictionary *msgDict = convertProtoMessage(&tConv.lastMessage);
    if (msgDict) {
        info[@"lastMessage"] = msgDict;
    }
    
    if(!tConv.draft.empty())
        info[@"draft"] = [NSString stringWithUTF8String:tConv.draft.c_str()];
    if(tConv.timestamp)
        info[@"timestamp"] = @(tConv.timestamp);
    
    NSMutableDictionary *unreadDict = convertProtoUnreadCount(tConv.unreadCount);
    if (unreadDict) {
        info[@"unreadCount"] = unreadDict;
    }

    if(tConv.isTop)
        info[@"isTop"] = @(tConv.isTop);
    if(tConv.isSilent)
        info[@"isSilent"] = @(tConv.isSilent);
    return info;
}

static NSMutableDictionary* convertProtoConversationSearchInfo(const mars::stn::TConversationSearchresult
                                                               &tConv) {
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *conversation = [[NSMutableDictionary alloc] init];
    conversation[@"type"] = @(tConv.conversationType);
    conversation[@"target"] = [NSString stringWithUTF8String:tConv.target.c_str()];
    conversation[@"line"] = @(tConv.line);
    info[@"conversation"] = conversation;
    NSMutableDictionary *msgDict = convertProtoMessage(&tConv.marchedMessage);
    if (msgDict) {
        info[@"marchedMessage"] = msgDict;
    }
    info[@"marchedCount"] = @(tConv.marchedCount);
    info[@"timestamp"] = @(tConv.timestamp);
    return info;
}

static NSMutableDictionary* convertProtoFriendRequest(const mars::stn::TFriendRequest &tRequest) {
    if (tRequest.target.empty()) {
        return nil;
    }
    NSMutableDictionary *request = [[NSMutableDictionary alloc] init];
    request[@"direction"] = @(tRequest.direction);
    request[@"target"] = [NSString stringWithUTF8String:tRequest.target.c_str()];
    if(!tRequest.reason.empty())
        request[@"reason"] = [NSString stringWithUTF8String:tRequest.reason.c_str()];
    request[@"status"] = @(tRequest.status);
    request[@"readStatus"] = @(tRequest.readStatus);
    request[@"timestamp"] = @(tRequest.timestamp);
    return request;
}

static NSMutableArray<NSMutableDictionary *> *convertProtoFriendRequests(std::list<mars::stn::TFriendRequest> &tRequests) {
    NSMutableArray *ret = [[NSMutableArray alloc] init];
    for (std::list<mars::stn::TFriendRequest>::iterator it = tRequests.begin(); it != tRequests.end(); it++) {
        NSMutableDictionary *request = convertProtoFriendRequest(*it);
        [ret addObject:request];
    }
    return ret;
}

static NSMutableArray<NSString *> *convertStdList(const std::list<std::string> &stdlist) {
    NSMutableArray *ret = [[NSMutableArray alloc] init];
    for (std::list<std::string>::const_iterator it = stdlist.begin(); it != stdlist.end(); it++) {
        [ret addObject:[NSString stringWithUTF8String:it->c_str()]];
    }
    return ret;
}


static NSMutableDictionary* convertProtoFileRecord(const mars::stn::TFileRecord &tfr) {
    NSMutableDictionary *record = [[NSMutableDictionary alloc] init];
    
    NSMutableDictionary *conversation = [[NSMutableDictionary alloc] init];
    record[@"conversation"] = conversation;
    conversation[@"type"] = @(tfr.conversationType);
    conversation[@"target"] = [NSString stringWithUTF8String:tfr.target.c_str()];
    conversation[@"line"] = @(tfr.line);

    record[@"messageUid"] = @(tfr.messageUid);
    record[@"userId"] = [NSString stringWithUTF8String:tfr.userId.c_str()];
    record[@"name"] = [NSString stringWithUTF8String:tfr.name.c_str()];
    record[@"url"] = [NSString stringWithUTF8String:tfr.url.c_str()];
    record[@"size"] = @(tfr.size);
    record[@"downloadCount"] = @(tfr.downloadCount);
    record[@"timestamp"] = @(tfr.timestamp);
    
    return record;
}

static NSMutableArray<NSMutableDictionary *> *convertProtoFileRecords(const std::list<mars::stn::TFileRecord> &tRequests) {
    NSMutableArray *ret = [[NSMutableArray alloc] init];
    for (std::list<mars::stn::TFileRecord>::const_iterator it = tRequests.begin(); it != tRequests.end(); it++) {
        NSMutableDictionary *request = convertProtoFileRecord(*it);
        [ret addObject:request];
    }
    return ret;
}

static NSMutableDictionary* convertProtoChatroomInfo(const mars::stn::TChatroomInfo &info) {
    NSMutableDictionary *chatroomInfo = [[NSMutableDictionary alloc] init];
    chatroomInfo[@"title"] = [NSString stringWithUTF8String:info.title.c_str()];
    chatroomInfo[@"desc"] = [NSString stringWithUTF8String:info.desc.c_str()];
    chatroomInfo[@"portrait"] = [NSString stringWithUTF8String:info.portrait.c_str()];
    chatroomInfo[@"extra"] = [NSString stringWithUTF8String:info.extra.c_str()];
    chatroomInfo[@"state"] = @(info.state);
    chatroomInfo[@"memberCount"] = @(info.memberCount);
    chatroomInfo[@"createDt"] = @(info.createDt);
    chatroomInfo[@"updateDt"] = @(info.updateDt);
    
    return chatroomInfo;
}

static NSMutableDictionary* convertProtoChatroomMemberInfo(const mars::stn::TChatroomMemberInfo &info) {
    NSMutableDictionary *memberInfo = [[NSMutableDictionary alloc] init];
    memberInfo[@"memberCount"] = @(info.memberCount);
    NSMutableArray *members = [[NSMutableArray alloc] init];
    for (std::list<std::string>::const_iterator it = info.olderMembers.begin(); it != info.olderMembers.end(); it++) {
        [members addObject:[NSString stringWithUTF8String:it->c_str()]];
    }
    memberInfo[@"members"] = members;
    return memberInfo;
}

class RPCB : public mars::stn::ReceiveMessageCallback {
public:
    RPCB(id<ReceiveMessageDelegate> delegate) : m_delegate(delegate) {}
    
    void onReceiveMessage(const std::list<mars::stn::TMessage> &messageList, bool hasMore) {
        if (m_delegate && !messageList.empty()) {
            NSMutableArray<NSMutableDictionary *> *messages = convertProtoMessageList(messageList, NO);
            [m_delegate onReceiveMessage:messages hasMore:hasMore];
        }
    }
    
    void onRecallMessage(const std::string &operatorId, long long messageUid) {
        if (m_delegate) {
            [m_delegate onRecallMessage:messageUid];
        }
    }
    
    void onDeleteMessage(long long messageUid) {
        if (m_delegate) {
            [m_delegate onDeleteMessage:messageUid];
        }
    }
    
    void onUserReceivedMessage(const std::map<std::string, int64_t> &userReceived) {
        if (m_delegate && !userReceived.empty()) {
            NSMutableDictionary *userRecvdDict = convertProtoUserReceivedList(userReceived);
            [m_delegate onMessageDelivered:userRecvdDict];
        }
    }
    
    void onUserReadedMessage(const std::list<mars::stn::TReadEntry> &userReceived) {
        if (m_delegate && !userReceived.empty()) {
            NSMutableArray<NSMutableDictionary *> *readList = convertProtoReadEntryList(userReceived);
            [m_delegate onMessageReaded:readList];
        }
    }
    
    id<ReceiveMessageDelegate> m_delegate;
};


class GUCB : public mars::stn::GetUserInfoCallback {
  public:
  GUCB(id<RefreshUserInfoDelegate> delegate) : m_delegate(delegate) {}
  
  void onSuccess(const std::list<mars::stn::TUserInfo> &userInfoList) {
      if(m_delegate && !userInfoList.empty()) {
          [m_delegate onUserInfoUpdated:converProtoUserInfos(userInfoList)];
      }
  }
  void onFalure(int errorCode) {
    
  }
  id<RefreshUserInfoDelegate> m_delegate;
};

class GGCB : public mars::stn::GetGroupInfoCallback {
  public:
  GGCB(id<RefreshGroupInfoDelegate> delegate) : m_delegate(delegate) {}
  
  void onSuccess(const std::list<mars::stn::TGroupInfo> &groupInfoList) {
      if(m_delegate && !groupInfoList.empty()) {
          [m_delegate onGroupInfoUpdated:convertProtoGroupInfos(groupInfoList)];
      }
  }
  void onFalure(int errorCode) {
  }
  id<RefreshGroupInfoDelegate> m_delegate;
};

class GGMCB : public mars::stn::GetGroupMembersCallback {
public:
    GGMCB(id<RefreshGroupMemberDelegate> delegate) : m_delegate(delegate) {}
    
    void onSuccess(const std::string &groupId, const std::list<mars::stn::TGroupMember> &groupMemberList) {
        if(m_delegate && !groupMemberList.empty()) {
            [m_delegate onGroupMemberUpdated:[NSString stringWithUTF8String:groupId.c_str()] members:convertProtoGroupMembers(groupMemberList)];
        }
    }
    void onFalure(int errorCode) {
    }
    id<RefreshGroupMemberDelegate> m_delegate;
};

class GCHCB : public mars::stn::GetChannelInfoCallback {
public:
    GCHCB(id<RefreshChannelInfoDelegate> delegate) : m_delegate(delegate) {}
    
    void onSuccess(const std::list<mars::stn::TChannelInfo> &channelInfoList) {
        if(m_delegate && !channelInfoList.empty()) {
            NSMutableArray<NSMutableDictionary *> *cs = convertProtoChannelInfoList(channelInfoList);
            [m_delegate onChannelInfoUpdated:cs];
        }
    }
    void onFalure(int errorCode) {
    }
    id<RefreshChannelInfoDelegate> m_delegate;
};

class GFLCB : public mars::stn::GetMyFriendsCallback {
public:
    GFLCB(id<RefreshFriendListDelegate> delegate) : m_delegate(delegate) {}
    void onSuccess(const std::list<std::string> &friendIdList) {
        if(m_delegate) {
            [m_delegate onFriendListUpdated:convertStdList(friendIdList)];
        }
    }
    void onFalure(int errorCode) {
        
    }
    id<RefreshFriendListDelegate> m_delegate;
};

class GFRCB : public mars::stn::GetFriendRequestCallback {
public:
    GFRCB(id<RefreshFriendRequestDelegate> delegate) : m_delegate(delegate) {}
    void onSuccess(const std::list<std::string> &newRequests) {
        if(m_delegate) {
            NSMutableArray<NSString *> *rs = convertStdList(newRequests);
            [m_delegate onFriendRequestsUpdated:rs];
        }
    }
    void onFalure(int errorCode) {
        
    }
    id<RefreshFriendRequestDelegate> m_delegate;
};

class GSCB : public mars::stn::GetSettingCallback {
public:
  GSCB(id<RefreshSettingDelegate> delegate) : m_delegate(delegate) {}
  void onSuccess(bool hasNewRequest) {
    if(m_delegate && hasNewRequest) {
      [m_delegate onSettingUpdated];
    }
  }
  void onFalure(int errorCode) {
    
  }
  id<RefreshSettingDelegate> m_delegate;
};


class CONFCB : public mars::stn::ConferenceEventCallback {
public:
  CONFCB(id<ConferenceEventDelegate> delegate) : m_delegate(delegate) {
  }
  void onConferenceEvent(const std::string &event) {
    if (m_delegate) {
        [m_delegate onConferenceEvent:[NSString stringWithUTF8String:event.c_str()]];
    }
  }
    
  id<ConferenceEventDelegate> m_delegate;
};



static void fillMessageContent(mars::stn::TMessageContent &content, NSDictionary *payload) {
    content.type = [payload[@"type"] intValue];
    content.searchableContent = payload[@"searchableContent"] ? [(NSString *)payload[@"searchableContent"] UTF8String] : "";
    content.pushContent = payload[@"pushContent"] ? [payload[@"pushContent"] UTF8String] : "";
    content.pushData = payload[@"pushData"] ? [payload[@"pushData"] UTF8String] : "";
    content.content = payload[@"content"] ? [payload[@"content"] UTF8String] : "";
    
    FlutterStandardTypedData *binaryData = payload[@"binaryContent"];
    if (binaryData) {
        NSData *data = binaryData.data;
        content.binaryContent = std::string((const char *)data.bytes, data.length);
    }
    
    content.localContent = payload[@"localContent"] ? [payload[@"localContent"] UTF8String] : "";
    content.mediaType = [payload[@"mediaType"] intValue];
    content.remoteMediaUrl = payload[@"remoteMediaUrl"] ? [payload[@"remoteMediaUrl"] UTF8String] : "";
    content.localMediaPath = payload[@"localMediaPath"] ? [payload[@"localMediaPath"] UTF8String] : "";
    content.mentionedType = [payload[@"mentionedtype"] intValue];

    NSArray<NSString *> *targets = payload[@"mentionedTargets"];
    if(targets.count) {
        for (NSString *t in targets) {
            content.mentionedTargets.push_back([t UTF8String]);
        }
    }
    
    content.extra = payload[@"extra"] ? [payload[@"extra"] UTF8String] : "";
}

static void fillTMessage(mars::stn::TMessage &tmsg, NSDictionary *convDict, NSDictionary *contDict) {
    tmsg.conversationType = [convDict[@"type"] intValue];
    tmsg.target = convDict[@"target"] ? [convDict[@"target"] UTF8String] : "";
    tmsg.line = [convDict[@"line"] intValue];
    tmsg.from = mars::app::GetAccountUserName();
    tmsg.status = mars::stn::MessageStatus::Message_Status_Sending;
    tmsg.timestamp = time(NULL)*1000;
    tmsg.direction = 0;
    fillMessageContent(tmsg.content, contDict);
}

class IMGeneralOperationCallback : public mars::stn::GeneralOperationCallback {
private:
    void(^m_successBlock)();
    void(^m_errorBlock)(int error_code);
public:
    IMGeneralOperationCallback(void(^successBlock)(), void(^errorBlock)(int error_code)) : mars::stn::GeneralOperationCallback(), m_successBlock(successBlock), m_errorBlock(errorBlock) {};
    void onSuccess() {
        if (m_successBlock) {
            m_successBlock();
        }
        delete this;
    }
    void onFalure(int errorCode) {
        if (m_errorBlock) {
            m_errorBlock(errorCode);
        }
        delete this;
    }

    virtual ~IMGeneralOperationCallback() {
        m_successBlock = nil;
        m_errorBlock = nil;
    }
};

class IMSendMessageCallback : public mars::stn::SendMsgCallback {
private:
    void(^m_successBlock)(long long messageUid, long long timestamp);
    void(^m_uploadedBlock)(NSString *remoteUrl);
    void(^m_errorBlock)(int error_code);
    void(^m_progressBlock)(long uploaded, long total);
    int mRequestId;
public:
    IMSendMessageCallback(int requestId, void(^successBlock)(long long messageUid, long long timestamp), void(^progressBlock)(long uploaded, long total), void(^uploadedBlock)(NSString *remoteUrl), void(^errorBlock)(int error_code)) : mars::stn::SendMsgCallback(), mRequestId(requestId), m_successBlock(successBlock), m_progressBlock(progressBlock), m_uploadedBlock(uploadedBlock), m_errorBlock(errorBlock)  {};
     void onSuccess(long long messageUid, long long timestamp) {
         m_successBlock(messageUid, timestamp);
         delete this;
     }
    void onFalure(int errorCode) {
        m_errorBlock(errorCode);
        delete this;
    }
    void onPrepared(long messageId, int64_t savedTime) {
        
    }
    void onMediaUploaded(std::string remoteUrl) {
        m_uploadedBlock([NSString stringWithUTF8String:remoteUrl.c_str()]);
    }
    
    void onProgress(int uploaded, int total) {
        m_progressBlock(uploaded, total);
    }
    
    virtual ~IMSendMessageCallback() {
        m_successBlock = nil;
        m_errorBlock = nil;
        m_progressBlock = nil;
    }
};

class IMLoadRemoteMessagesCallback : public mars::stn::LoadRemoteMessagesCallback {
private:
    void(^m_successBlock)(const std::list<mars::stn::TMessage> &messageList);
    void(^m_errorBlock)(int error_code);
public:
    IMLoadRemoteMessagesCallback(void(^successBlock)(const std::list<mars::stn::TMessage> &messageList), void(^errorBlock)(int error_code)) : mars::stn::LoadRemoteMessagesCallback(), m_successBlock(successBlock), m_errorBlock(errorBlock) {};
    void onSuccess(const std::list<mars::stn::TMessage> &messageList) {
        if (m_successBlock)
            m_successBlock(messageList);
        delete this;
    }
    void onFalure(int errorCode) {
        if (m_errorBlock) {
            m_errorBlock(errorCode);
        }
        delete this;
    }
    
    virtual ~IMLoadRemoteMessagesCallback() {
        m_successBlock = nil;
        m_errorBlock = nil;
    }
};

class RecallMessageCallback : public mars::stn::GeneralOperationCallback {
private:
    void(^m_successBlock)();
    void(^m_errorBlock)(int error_code);
public:
    RecallMessageCallback(void(^successBlock)(), void(^errorBlock)(int error_code)) : mars::stn::GeneralOperationCallback(), m_successBlock(successBlock), m_errorBlock(errorBlock) {};
    void onSuccess() {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (m_successBlock) {
                m_successBlock();
            }
            delete this;
        });
    }
    void onFalure(int errorCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (m_errorBlock) {
                m_errorBlock(errorCode);
            }
            delete this;
        });
    }
    
    virtual ~RecallMessageCallback() {
        m_successBlock = nil;
        m_errorBlock = nil;
    }
};

class GeneralUpdateMediaCallback : public mars::stn::UpdateMediaCallback {
public:
  void(^m_successBlock)(NSString *remoteUrl);
  void(^m_errorBlock)(int error_code);
  void(^m_progressBlock)(long uploaded, long total);
  
  GeneralUpdateMediaCallback(void(^successBlock)(NSString *remoteUrl), void(^progressBlock)(long uploaded, long total), void(^errorBlock)(int error_code)) : mars::stn::UpdateMediaCallback(), m_successBlock(successBlock), m_progressBlock(progressBlock), m_errorBlock(errorBlock) {}
  
  void onSuccess(const std::string &remoteUrl) {
      NSString *url = [NSString stringWithUTF8String:remoteUrl.c_str()];
      dispatch_async(dispatch_get_main_queue(), ^{
          if (m_successBlock) {
              m_successBlock(url);
          }
          delete this;
      });
  }
  
  void onFalure(int errorCode) {
      dispatch_async(dispatch_get_main_queue(), ^{
          if (m_errorBlock) {
              m_errorBlock(errorCode);
          }
          delete this;
      });
  }
  
    void onProgress(int current, int total) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (m_progressBlock) {
                m_progressBlock(current, total);
            }
        });
    }
    
  ~GeneralUpdateMediaCallback() {
    m_successBlock = nil;
    m_errorBlock = nil;
  }
};

class IMSearchUserCallback : public mars::stn::SearchUserCallback {
private:
    void(^m_successBlock)(const std::list<mars::stn::TUserInfo> &users);
    void(^m_errorBlock)(int errorCode);
public:
    IMSearchUserCallback(void(^successBlock)(const std::list<mars::stn::TUserInfo> &users), void(^errorBlock)(int errorCode)) : m_successBlock(successBlock), m_errorBlock(errorBlock) {}
    
    void onSuccess(const std::list<mars::stn::TUserInfo> &users, const std::string &keyword, int page) {
        m_successBlock(users);
        delete this;
    }
    void onFalure(int errorCode) {
        m_errorBlock(errorCode);
        delete this;
    }
    
    ~IMSearchUserCallback() {}
};

class IMGetOneUserInfoCallback : public mars::stn::GetOneUserInfoCallback {
private:
    void(^m_successBlock)(const mars::stn::TUserInfo &tUserInfo);
    void(^m_errorBlock)(int errorCode);
public:
    IMGetOneUserInfoCallback(void(^successBlock)(const mars::stn::TUserInfo &tUserInfo), void(^errorBlock)(int errorCode)) : m_successBlock(successBlock), m_errorBlock(errorBlock) {}
    
    void onSuccess(const mars::stn::TUserInfo &tUserInfo) {
        if(m_successBlock) {
            m_successBlock(tUserInfo);
        }
        delete this;
    }
    
    void onFalure(int errorCode) {
        if(m_errorBlock) {
            m_errorBlock(errorCode);
        }
        delete this;
    }
    
    ~IMGetOneUserInfoCallback() {}
};

class IMGetGroupMembersCallback : public mars::stn::GetGroupMembersCallback {
private:
    void(^m_successBlock)(const std::list<mars::stn::TGroupMember> &groupMemberList);
    void(^m_errorBlock)(int error_code);
public:
    IMGetGroupMembersCallback(void(^successBlock)(const std::list<mars::stn::TGroupMember> &groupMemberList), void(^errorBlock)(int error_code)) : mars::stn::GetGroupMembersCallback(), m_successBlock(successBlock), m_errorBlock(errorBlock) {};
    
    void onSuccess(const std::string &groupId, const std::list<mars::stn::TGroupMember> &groupMemberList) {
            if(m_successBlock) {
                m_successBlock(groupMemberList);
            }
            delete this;
    }
    void onFalure(int errorCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(m_errorBlock) {
                m_errorBlock(errorCode);
            }
            delete this;
        });
    }
    
    virtual ~IMGetGroupMembersCallback() {
        m_successBlock = nil;
        m_errorBlock = nil;
    }
};

class IMGetOneGroupInfoCallback : public mars::stn::GetOneGroupInfoCallback {
private:
    void(^m_successBlock)(const mars::stn::TGroupInfo &tgi);
    void(^m_errorBlock)(int error_code);
public:
    IMGetOneGroupInfoCallback(void(^successBlock)(const mars::stn::TGroupInfo &tgi), void(^errorBlock)(int error_code)) : mars::stn::GetOneGroupInfoCallback(), m_successBlock(successBlock), m_errorBlock(errorBlock) {};
    
    void onSuccess(const mars::stn::TGroupInfo &tgi) {
            if (m_successBlock) {
                m_successBlock(tgi);
            }
                
            delete this;
    }
    void onFalure(int errorCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (m_errorBlock) {
                m_errorBlock(errorCode);
            }
            delete this;
        });
    }
    
    virtual ~IMGetOneGroupInfoCallback() {
        m_successBlock = nil;
        m_errorBlock = nil;
    }
};

class IMCreateGroupCallback : public mars::stn::CreateGroupCallback {
private:
    void(^m_successBlock)(NSString *groupId);
    void(^m_errorBlock)(int error_code);
public:
    IMCreateGroupCallback(void(^successBlock)(NSString *groupId), void(^errorBlock)(int error_code)) : mars::stn::CreateGroupCallback(), m_successBlock(successBlock), m_errorBlock(errorBlock) {};
    void onSuccess(std::string groupId) {
        NSString *nsstr = [NSString stringWithUTF8String:groupId.c_str()];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (m_successBlock) {
                m_successBlock(nsstr);
            }
            delete this;
        });
    }
    void onFalure(int errorCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (m_errorBlock) {
                m_errorBlock(errorCode);
            }
            delete this;
        });
    }

    virtual ~IMCreateGroupCallback() {
        m_successBlock = nil;
        m_errorBlock = nil;
    }
};

class IMGeneralStringCallback : public mars::stn::GeneralStringCallback {
private:
    void(^m_successBlock)(NSString *generalStr);
    void(^m_errorBlock)(int error_code);
public:
    IMGeneralStringCallback(void(^successBlock)(NSString *groupId), void(^errorBlock)(int error_code)) : mars::stn::GeneralStringCallback(), m_successBlock(successBlock), m_errorBlock(errorBlock) {};
    void onSuccess(std::string str) {
        NSString *nsstr = [NSString stringWithUTF8String:str.c_str()];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (m_successBlock) {
                m_successBlock(nsstr);
            }
            delete this;
        });
    }
    void onFalure(int errorCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (m_errorBlock) {
                m_errorBlock(errorCode);
            }
            delete this;
        });
    }

    virtual ~IMGeneralStringCallback() {
        m_successBlock = nil;
        m_errorBlock = nil;
    }
};

class IMLoadFileRecordCallback : public mars::stn::LoadFileRecordCallback {
private:
    void(^m_successBlock)(const std::list<mars::stn::TFileRecord> &fileList);
    void(^m_errorBlock)(int error_code);
public:
    IMLoadFileRecordCallback(void(^successBlock)(const std::list<mars::stn::TFileRecord> &fileList), void(^errorBlock)(int error_code)) : mars::stn::LoadFileRecordCallback(), m_successBlock(successBlock), m_errorBlock(errorBlock) {};
    void onSuccess(const std::list<mars::stn::TFileRecord> &fileList) {
        if (m_successBlock) {
            m_successBlock(fileList);
        }
        delete this;
    }
    void onFalure(int errorCode) {
        if (m_errorBlock) {
            m_errorBlock(errorCode);
        }
        delete this;
    }
    
    virtual ~IMLoadFileRecordCallback() {
        m_successBlock = nil;
        m_errorBlock = nil;
    }
};

class IMCreateChannelCallback : public mars::stn::CreateChannelCallback {
private:
    void(^m_successBlock)(const mars::stn::TChannelInfo &channelInfo);
    void(^m_errorBlock)(int error_code);
public:
    IMCreateChannelCallback(void(^successBlock)(const mars::stn::TChannelInfo &channelInfo), void(^errorBlock)(int error_code)) : mars::stn::CreateChannelCallback(), m_successBlock(successBlock), m_errorBlock(errorBlock) {};
    void onSuccess(const mars::stn::TChannelInfo &channelInfo) {
            if (m_successBlock) {
                m_successBlock(channelInfo);
            }
            delete this;
    }
    void onFalure(int errorCode) {
            if (m_errorBlock) {
                m_errorBlock(errorCode);
            }
            delete this;
    }
    
    virtual ~IMCreateChannelCallback() {
        m_successBlock = nil;
        m_errorBlock = nil;
    }
};

class IMSearchChannelCallback : public mars::stn::SearchChannelCallback {
private:
    void(^m_successBlock)(const std::list<mars::stn::TChannelInfo> &channels);
    void(^m_errorBlock)(int errorCode);
public:
    IMSearchChannelCallback(void(^successBlock)(const std::list<mars::stn::TChannelInfo> &channels), void(^errorBlock)(int errorCode)) : m_successBlock(successBlock), m_errorBlock(errorBlock) {}
    
    void onSuccess(const std::list<mars::stn::TChannelInfo> &channels, const std::string &keyword) {
        m_successBlock(channels);
        delete this;
    }
    void onFalure(int errorCode) {
        m_errorBlock(errorCode);
        delete this;
    }
    
    ~IMSearchChannelCallback() {}
};

class IMGetChatroomInfoCallback : public mars::stn::GetChatroomInfoCallback {
private:
    void(^m_successBlock)(const mars::stn::TChatroomInfo &info);
    void(^m_errorBlock)(int error_code);
public:
    IMGetChatroomInfoCallback(void(^successBlock)(const mars::stn::TChatroomInfo &info), void(^errorBlock)(int error_code)) : mars::stn::GetChatroomInfoCallback(), m_successBlock(successBlock), m_errorBlock(errorBlock) {};
    void onSuccess(const mars::stn::TChatroomInfo &info) {
        if (m_successBlock) {
            m_successBlock(info);
        }
        delete this;
    }
    void onFalure(int errorCode) {
        if (m_errorBlock) {
            m_errorBlock(errorCode);
        }
        delete this;
    }
    
    virtual ~IMGetChatroomInfoCallback() {
        m_successBlock = nil;
        m_errorBlock = nil;
    }
};

class IMGetChatroomMemberInfoCallback : public mars::stn::GetChatroomMemberInfoCallback {
private:
    void(^m_successBlock)(const mars::stn::TChatroomMemberInfo &info);
    void(^m_errorBlock)(int error_code);
public:
    IMGetChatroomMemberInfoCallback(void(^successBlock)(const mars::stn::TChatroomMemberInfo &info), void(^errorBlock)(int error_code)) : mars::stn::GetChatroomMemberInfoCallback(), m_successBlock(successBlock), m_errorBlock(errorBlock) {};
    void onSuccess(const mars::stn::TChatroomMemberInfo &info) {
        if (m_successBlock) {
            m_successBlock(info);
        }
        delete this;
    }
    void onFalure(int errorCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (m_errorBlock) {
                m_errorBlock(errorCode);
            }
            delete this;
        });
    }
    
    virtual ~IMGetChatroomMemberInfoCallback() {
        m_successBlock = nil;
        m_errorBlock = nil;
    }
};

@interface FlutterImclientPlugin () <ConnectionStatusDelegate, ReceiveMessageDelegate, RefreshUserInfoDelegate, RefreshGroupInfoDelegate, WFCCNetworkStatusDelegate, RefreshFriendListDelegate, RefreshFriendRequestDelegate, RefreshSettingDelegate, RefreshChannelInfoDelegate, RefreshGroupMemberDelegate, ConferenceEventDelegate>
@property(nonatomic, assign)BOOL isInited;
@property(nonatomic, strong)NSString *userId;
@property(nonatomic, assign)ConnectionStatus connectionStatus;

@property(nonatomic, assign, getter=isLogined)BOOL logined;

@property(nonatomic, strong)NSString *deviceToken;
@property(nonatomic, strong)NSString *voipDeviceToken;
@property(nonatomic, assign)BOOL deviceTokenUploaded;
@property(nonatomic, assign)BOOL voipDeviceTokenUploaded;


@property(nonatomic, assign)UIBackgroundTaskIdentifier bgTaskId;
@property(nonatomic, strong)NSTimer *forceConnectTimer;
@property(nonatomic, strong)NSTimer *suspendTimer;
@property(nonatomic, strong)NSTimer *endBgTaskTimer;
@property(nonatomic, assign)NSUInteger backgroudRunTime;

@property(nonatomic, strong)FlutterMethodChannel* channel;
@end

FlutterImclientPlugin *gIMClientInstance = [[FlutterImclientPlugin alloc] init];
@implementation FlutterImclientPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"flutter_imclient"
            binaryMessenger:[registrar messenger]];
    gIMClientInstance.channel = channel;
  [registrar addMethodCallDelegate:gIMClientInstance channel:channel];
  [gIMClientInstance initClient];
}

+ (void)setDeviceToken:(NSString *)deviceToken {
    gIMClientInstance.deviceToken = deviceToken;
}

- (void)setDeviceToken:(NSString *)token {
    if (token.length == 0) {
        return;
    }

    _deviceToken = token;

    if (!self.isLogined || self.connectionStatus != kConnectionStatusConnected) {
        self.deviceTokenUploaded = NO;
        return;
    }
  
    NSString *appName =
    [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
    mars::stn::setDeviceToken([appName UTF8String], [token UTF8String], mars::app::AppCallBack::Instance()->GetPushType());
    self.deviceTokenUploaded =YES;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else if([@"isLogined" isEqual:call.method]) {
      result(@(self.isLogined));
  } else if([@"connect" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *host = dict[@"host"];
      self.userId = dict[@"userId"];
      NSString *token = dict[@"token"];
      
      [self connect:host userId:self.userId token:token result:result];
  } else if([@"currentUserId" isEqualToString:call.method]) {
      result(self.userId);
  } else if([@"connectionStatus" isEqualToString:call.method]) {
      result(@(self.connectionStatus));
  } else if([@"isLogined" isEqualToString:call.method]) {
      result(@(self.logined));
  } else if([@"getClientId" isEqualToString:call.method]) {
      NSString *clientId = [NSString stringWithUTF8String:mars::app::AppCallBack::Instance()->GetDeviceInfo().clientid.c_str()];
      result(clientId);
  } else if([@"serverDeltaTime" isEqual:call.method]) {
      result(@(mars::stn::getServerDeltaTime()));
  } else if([@"registeMessage" isEqual:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int type = [dict[@"type"] intValue];
      int flag = [dict[@"flag"] intValue];
      mars::stn::MessageDB::Instance()->RegisterMessageFlag(type, flag);
      result(nil);
  } else if([@"disconnect" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      BOOL disablePush = [dict[@"disablePush"] boolValue];
      BOOL clearSession = [dict[@"clearSession"] boolValue];
      [self disconnect:disablePush clearSession:clearSession];
      result(nil);
  } else if([@"startLog" isEqualToString:call.method]) {
      [self.class startLog];
      result(nil);
  } else if([@"stopLog" isEqualToString:call.method]) {
      [self.class stopLog];
      result(nil);
  } else if([@"getLogFilesPath" isEqualToString:call.method]) {
      result([self.class getLogFilesPath]);
  } else if([@"getConversationInfos" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSArray *types = dict[@"types"];
      NSArray *lines = dict[@"lines"];
      [self getConversationInfos:types lines:lines result:result];
  }else if([@"getConversationInfo" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      [self getConversationInfo:dict result:result];
  }else if([@"searchConversation" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSArray *types = dict[@"types"];
      NSArray *lines = dict[@"lines"];
      [self searchConversation:dict[@"keyword"] types:types lines:lines result:result];
  }else if([@"removeConversation" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *conversation = dict[@"conversation"];
      BOOL clearMessage = [dict[@"clearMessage"] boolValue];
      [self removeConversation:conversation clearMessage:clearMessage];
      result(nil);
  }else if([@"setConversationTop" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSDictionary *convDict = dict[@"conversation"];
      BOOL isTop = [dict[@"isTop"] boolValue];
      [self set:requestId Conversation:convDict top:isTop];
      result(nil);
  }else if([@"setConversationSilent" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSDictionary *convDict = dict[@"conversation"];
      BOOL isSilent = [dict[@"isSilent"] boolValue];
      [self set:requestId Conversation:convDict silent:isSilent];
      result(nil);
  }else if([@"setConversationDraft" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSDictionary *convDict = dict[@"conversation"];
      NSString *draft = dict[@"draft"];
      [self set:requestId Conversation:convDict draft:draft];
      result(nil);
  }else if([@"setConversationTimestamp" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSDictionary *convDict = dict[@"conversation"];
      long long timestamp = [dict[@"timestamp"] longLongValue];
      [self set:requestId Conversation:convDict timestamp:timestamp];
      result(nil);
  }else if([@"getFirstUnreadMessageId" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *convDict = dict[@"conversation"];
      [self getFirstUnreadMessageIdOf:convDict result:result];
  } else if([@"getConversationUnreadCount" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *convDict = dict[@"conversation"];
      [self getConversationUnreadCount:convDict result:result];
  } else if([@"getConversationsUnreadCount" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSArray *types = dict[@"types"];
      NSArray *lines = dict[@"lines"];
      [self getConversationsUnreadCount:types lines:lines result:result];
  } else if([@"clearConversationUnreadStatus" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *conversation = dict[@"conversation"];
      int type = [conversation[@"type"] intValue];
      NSString *target = conversation[@"target"];
      int line = [conversation[@"line"] intValue];
      result(@(mars::stn::MessageDB::Instance()->ClearUnreadStatus(type, [target UTF8String], line)));
  } else if([@"clearConversationsUnreadStatus" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSArray *conversationTypes = dict[@"types"];
      NSArray *lines = dict[@"lines"];
      std::list<int> types;
      for (NSNumber *type in conversationTypes) {
          types.push_back([type intValue]);
      }

      std::list<int> ls;
      for (NSNumber *type in lines) {
          ls.push_back([type intValue]);
      }
      result(@(mars::stn::MessageDB::Instance()->ClearUnreadStatus(types, ls)));
  } else if([@"getConversationRead" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *convDict = dict[@"conversation"];
      [self getConversationRead:convDict result:result];
  } else if([@"getMessageDelivery" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *convDict = dict[@"conversation"];
      [self getMessageDelivery:convDict result:result];
  } else if([@"getMessages" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *convDict = dict[@"conversation"];
      NSArray<NSNumber *> *contentTypes = dict[@"contentTypes"];
      NSString *withUser = dict[@"withUser"];
      long long fromIndex = [dict[@"fromIndex"] longLongValue];
      int count = [dict[@"count"] intValue];
      
      [self getMessages:convDict contentTypes:contentTypes from:fromIndex count:count withUser:withUser result:result];
  } else if([@"getMessagesByStatus" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *convDict = dict[@"conversation"];
      NSArray<NSNumber *> *messageStatus = dict[@"messageStatus"];
      NSString *withUser = dict[@"withUser"];
      long long fromIndex = [dict[@"fromIndex"] longLongValue];
      int count = [dict[@"count"] intValue];;
      
      [self getMessages:convDict messageStatus:messageStatus from:fromIndex count:count withUser:withUser result:result];
  } else if([@"getConversationsMessages" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSArray *types = dict[@"types"];
      NSArray *lines = dict[@"lines"];
      NSArray<NSNumber *> *contentTypes = dict[@"contentTypes"];
      NSString *withUser = dict[@"withUser"];
      long long fromIndex = [dict[@"fromIndex"] longLongValue];
      int count = [dict[@"count"] intValue];
      
      [self getConversationsMessages:types lines:lines contentTypes:contentTypes from:fromIndex count:count withUser:withUser result:result];
  } else if([@"getConversationsMessageByStatus" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSArray *types = dict[@"types"];
      NSArray *lines = dict[@"lines"];
      NSArray<NSNumber *> *messageStatus = dict[@"messageStatus"];
      NSString *withUser = dict[@"withUser"];
      long long fromIndex = [dict[@"fromIndex"] longLongValue];
      int count = [dict[@"count"] intValue];
      [self getConversationsMessages:types lines:lines messageStatus:messageStatus from:fromIndex count:count withUser:withUser result:result];
  } else if([@"getRemoteMessages" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *convDict = dict[@"conversation"];
      int requestId = [dict[@"requestId"] intValue];
      long long beforeMessageUid = [dict[@"beforeMessageUid"] longLongValue];
      int count = [dict[@"count"] intValue];
      
      [self getRemoteMessages:convDict before:beforeMessageUid count:count ofRequest:requestId];
      result(nil);
  } else if([@"getMessage" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      long messageId = [dict[@"messageId"] longValue];
      mars::stn::TMessage tmsg = mars::stn::MessageDB::Instance()->GetMessageById(messageId);
      result(convertProtoMessage(&tmsg));
  } else if([@"getMessageByUid" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      long messageUid = [dict[@"messageUid"] longLongValue];
      mars::stn::TMessage tmsg = mars::stn::MessageDB::Instance()->GetMessageByUid(messageUid);
      result(convertProtoMessage(&tmsg));
  } else if([@"searchMessages" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *convDict = dict[@"conversation"];
      NSString *keyword = dict[@"keyword"];
      BOOL order = [dict[@"order"] boolValue];
      int limit = [dict[@"limit"] intValue];
      int offset = [dict[@"offset"] intValue];
      
      if (keyword.length == 0 || limit == 0) {
          result(nil);
          return;
      }
      
      int type = [convDict[@"type"] intValue];
      std::string target = [convDict[@"target"] UTF8String];
      int line = [convDict[@"line"] intValue];
      
      std::list<mars::stn::TMessage> tmessages = mars::stn::MessageDB::Instance()->SearchMessages(type, target, line, [keyword UTF8String], order ? true : false, limit, offset);
      
      result(convertProtoMessageList(tmessages, YES));
  } else if([@"searchConversationsMessages" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSArray *conversationTypes = dict[@"types"];
      NSArray *lines = dict[@"lines"];
      NSString *keyword = dict[@"keyword"];
      NSArray<NSNumber *> *contentTypes = dict[@"contentTypes"];
      long long fromIndex = [dict[@"fromIndex"] intValue];
      int count = [dict[@"count"] intValue];
      
      std::list<int> convtypes;
      for (NSNumber *ct in conversationTypes) {
          convtypes.push_back([ct intValue]);
      }
      
      std::list<int> ls;
      for (NSNumber *type in lines) {
          ls.push_back([type intValue]);
      }
      
      
      std::list<int> types;
      if (![contentTypes isKindOfClass:[NSNull class]]) {
          for (NSNumber *num in contentTypes) {
              types.push_back(num.intValue);
          }
      }
      
      bool direction = true;
      if (count < 0) {
          direction = false;
          count = -count;
      }
      
      std::list<mars::stn::TMessage> tmessages = mars::stn::MessageDB::Instance()->SearchMessagesEx(convtypes, ls, [keyword UTF8String], types, direction, (int)count, fromIndex);
      result(convertProtoMessageList(tmessages, false));
  } else if([@"sendMessage" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSDictionary *convDict = dict[@"conversation"];
      NSDictionary *contDict = dict[@"content"];
      NSArray<NSString *> *toUsers = dict[@"toUsers"];
      int expireDuration = [dict[@"expireDuration"] intValue];
      [self sendMessage:requestId conversation:convDict content:contDict toUsers:toUsers expireDuration:expireDuration result:result];
  } else if([@"sendSavedMessage" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      long messageId = [dict[@"messageId"] longValue];
      int expireDuration = [dict[@"expireDuration"] intValue];
      
      if(mars::stn::sendMessageEx(messageId, new IMSendMessageCallback(requestId, ^(long long messageUid, long long timestamp) {
          [self.channel invokeMethod:@"onSendMessageSuccess" arguments:@{@"requestId":@(requestId), @"messageUid":@(messageUid), @"timestamp":@(timestamp)}];
      },nil,nil,^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }), expireDuration)) {
          result(@(YES));
      } else {
          result(@(YES));
      }
  } else if([@"recallMessage" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      long long messageUid = [dict[@"messageUid"] longLongValue];
      
      mars::stn::recallMessage(messageUid, new RecallMessageCallback(^(void){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"uploadMedia" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *fileName = dict[@"fileName"];
      int mediaType = [dict[@"mediaType"] intValue];
      FlutterStandardTypedData *binaryData = dict[@"mediaData"];
      NSData *mediaData = binaryData.data;
      
      mars::stn::uploadGeneralMedia(fileName == nil ? "" : [fileName UTF8String], std::string((char *)mediaData.bytes, mediaData.length), (int)mediaType, new GeneralUpdateMediaCallback(^(NSString *remoteUrl) {
          [self.channel invokeMethod:@"onSendMediaMessageUploaded" arguments:@{@"requestId":@(requestId), @"remoteUrl":remoteUrl}];
      }, ^(long uploaded, long total) {
          [self.channel invokeMethod:@"onSendMediaMessageProgress" arguments:@{@"requestId":@(requestId), @"uploaded":@(uploaded), @"total":@(total)}];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"deleteMessage" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      long messageId = [dict[@"messageId"] longValue];
      result(@(mars::stn::MessageDB::Instance()->DeleteMessage(messageId) > 0));
  } else if([@"clearMessages" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *convDict = dict[@"conversation"];
      long long beforeTime = [dict[@"before"] longLongValue];
      
      int type = [convDict[@"type"] intValue];
      std::string target = [convDict[@"target"] UTF8String];
      int line = [convDict[@"line"] intValue];

      if(beforeTime) {
          result(@(mars::stn::MessageDB::Instance()->ClearMessages(type, target, line, beforeTime)));
      } else {
          result(@(mars::stn::MessageDB::Instance()->ClearMessages(type, target, line)));
      }
  } else if([@"setMediaMessagePlayed" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      long messageId = [dict[@"messageId"] longValue];
      
      result(@(mars::stn::MessageDB::Instance()->updateMessageStatus(messageId, mars::stn::Message_Status_Played)));
  } else if([@"insertMessage" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *conversation = dict[@"conversation"];
      NSDictionary *content = dict[@"content"];
      int status = [dict[@"status"] intValue];
      long long serverTime = [dict[@"serverTime"] longLongValue];
      
      mars::stn::TMessage tmsg;
      fillTMessage(tmsg, conversation, content);
      
      if(status >= mars::stn::Message_Status_Unread) {
          tmsg.direction = 1;
      }
      
      tmsg.from = [self.userId UTF8String];
      
      tmsg.status = (mars::stn::MessageStatus)status;
      tmsg.timestamp = serverTime;
      
      long msgId = mars::stn::MessageDB::Instance()->InsertMessage(tmsg);
      result(@(msgId));
  } else if([@"updateMessage" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *content = dict[@"content"];
      long messageId = [((NSString*) dict[@"messageId"]) longLongValue];

      mars::stn::TMessageContent tmc;
      fillMessageContent(tmc, content);
      result(@(mars::stn::MessageDB::Instance()->UpdateMessageContent(messageId, tmc)));
  } else if([@"updateMessageStatus" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int status = [dict[@"status"] intValue];
      long messageId = [((NSString*) dict[@"messageId"]) longLongValue];
      result(@(mars::stn::MessageDB::Instance()->updateMessageStatus(messageId, (mars::stn::MessageStatus)status)));
  } else if([@"getMessageCount" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary *convDict = dict[@"conversation"];
      int type = [convDict[@"type"] intValue];
      std::string target = [convDict[@"target"] UTF8String];
      int line = [convDict[@"line"] intValue];
      
      result(@(mars::stn::MessageDB::Instance()->GetMsgTotalCount(type, target, line)));
  } else if([@"getUserInfo" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *userId = dict[@"userId"];
      BOOL refresh = [dict[@"refresh"] boolValue];
      NSString *groupId = dict[@"groupId"];
      
      mars::stn::TUserInfo tui = mars::stn::MessageDB::Instance()->getUserInfo([userId UTF8String], groupId ? [groupId UTF8String] : "", refresh);
      if (!tui.uid.empty()) {
          result(convertProtoUserInfo(tui));
      } else {
          result(nil);
      }
  } else if([@"getUserInfos" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSArray<NSString *> *userIds = dict[@"userIds"];
      NSString *groupId = dict[@"groupId"];
      
      std::list<std::string> strIds;
      for (NSString *userId in userIds) {
          strIds.insert(strIds.end(), [userId UTF8String]);
      }
      std::list<mars::stn::TUserInfo> tuis = mars::stn::MessageDB::Instance()->getUserInfos(strIds, groupId ? [groupId UTF8String] : "");
      
      NSMutableArray<NSMutableDictionary *> *ret = [[NSMutableArray alloc] init];
      for (std::list<mars::stn::TUserInfo>::iterator it = tuis.begin(); it != tuis.end(); it++) {
          NSMutableDictionary *userInfo = convertProtoUserInfo(*it);
          [ret addObject:userInfo];
      }
      result(ret);
  } else if([@"searchUser" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *keyword = dict[@"keyword"];
      int searchType = [dict[@"searchType"] intValue];
      int page = [dict[@"page"] intValue];
      int requestId = [dict[@"requestId"] intValue];
      
      mars::stn::searchUser([keyword UTF8String], (int)searchType, page, new IMSearchUserCallback(^(const std::list<mars::stn::TUserInfo> &tUserInfos) {
          [self.channel invokeMethod:@"onSearchUserResult" arguments:@{@"requestId":@(requestId), @"users":converProtoUserInfos(tUserInfos)}];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getUserInfoAsync" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *userId = dict[@"userId"];
      BOOL refresh = [dict[@"refresh"] boolValue];
      
      
      mars::stn::MessageDB::Instance()->GetUserInfo([userId UTF8String], refresh, new IMGetOneUserInfoCallback(^(const mars::stn::TUserInfo &tUserInfo) {
          [self.channel invokeMethod:@"getUserInfoAsyncCallback" arguments:@{@"requestId":@(requestId), @"user":convertProtoUserInfo(tUserInfo)}];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"isMyFriend" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *userId = dict[@"userId"];
      
      result(@(mars::stn::MessageDB::Instance()->isMyFriend([userId UTF8String])));
  } else if([@"getMyFriendList" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      BOOL refresh = dict[@"refresh"];
      
      NSMutableArray *ret = [[NSMutableArray alloc] init];
      std::list<std::string> friendList = mars::stn::MessageDB::Instance()->getMyFriendList(refresh);
      for (std::list<std::string>::iterator it = friendList.begin(); it != friendList.end(); it++) {
          [ret addObject:[NSString stringWithUTF8String:(*it).c_str()]];
      }
      result(ret);
  } else if([@"searchFriends" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *keyword = dict[@"keyword"];
      std::list<mars::stn::TUserInfo> friends = mars::stn::MessageDB::Instance()->SearchFriends([keyword UTF8String], 50);
      NSMutableArray<NSMutableDictionary *> *ret = [[NSMutableArray alloc] init];
      for (std::list<mars::stn::TUserInfo>::iterator it = friends.begin(); it != friends.end(); it++) {
          NSMutableDictionary *userInfo = convertProtoUserInfo(*it);
          if (userInfo) {
              [ret addObject:userInfo];
          }
      }
    result(ret);
  } else if([@"searchGroups" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *keyword = dict[@"keyword"];
      
      std::list<mars::stn::TGroupSearchResult> groups = mars::stn::MessageDB::Instance()->SearchGroups([keyword UTF8String], 50);
      NSMutableArray<NSMutableDictionary *> *ret = [[NSMutableArray alloc] init];
      for (std::list<mars::stn::TGroupSearchResult>::iterator it = groups.begin(); it != groups.end(); it++) {
          
          [ret addObject:convertProtoGroupSearchResult(*it)];
      }
      result(ret);
  } else if([@"getIncommingFriendRequest" isEqualToString:call.method]) {
      std::list<mars::stn::TFriendRequest> tRequests = mars::stn::MessageDB::Instance()->getFriendRequest(1);
      result(convertProtoFriendRequests(tRequests));
  } else if([@"getOutgoingFriendRequest" isEqualToString:call.method]) {
      std::list<mars::stn::TFriendRequest> tRequests = mars::stn::MessageDB::Instance()->getFriendRequest(0);
      result(convertProtoFriendRequests(tRequests));
  } else if([@"getFriendRequest" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *userId = dict[@"userId"];
      int direction = [dict[@"direction"] intValue];
      
      mars::stn::TFriendRequest tRequest = mars::stn::MessageDB::Instance()->getFriendRequest([userId UTF8String], direction);
      result(convertProtoFriendRequest(tRequest));
  } else if([@"loadFriendRequestFromRemote" isEqualToString:call.method]) {
      mars::stn::loadFriendRequestFromRemote();
      result(nil);
  } else if([@"getUnreadFriendRequestStatus" isEqualToString:call.method]) {
      result(@(mars::stn::MessageDB::Instance()->unreadFriendRequest()));
  } else if([@"clearUnreadFriendRequestStatus" isEqualToString:call.method]) {
      result(@(mars::stn::MessageDB::Instance()->clearUnreadFriendRequestStatus()));
  } else if([@"deleteFriend" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *userId = dict[@"userId"];
      int requestId = [dict[@"requestId"] intValue];
      
      mars::stn::deleteFriend([userId UTF8String], new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"sendFriendRequest" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *userId = dict[@"userId"];
      NSString *reason = dict[@"reason"];
      int requestId = [dict[@"requestId"] intValue];
      
      mars::stn::sendFriendRequest([userId UTF8String], [reason UTF8String], new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"handleFriendRequest" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *userId = dict[@"userId"];
      NSString *extra = dict[@"extra"];
      int requestId = [dict[@"requestId"] intValue];
      bool accept = [dict[@"accept"] boolValue];
      
      mars::stn::handleFriendRequest([userId UTF8String], accept, extra ? [extra UTF8String] : "", new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getFriendAlias" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *friendId = dict[@"friendId"];
      
      std::string strAlias = mars::stn::MessageDB::Instance()->GetFriendAlias([friendId UTF8String]);
      result([NSString stringWithUTF8String:strAlias.c_str()]);
  } else if([@"setFriendAlias" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *friendId = dict[@"friendId"];
      NSString *alias = dict[@"alias"];
      int requestId = [dict[@"requestId"] intValue];
      
      mars::stn::setFriendAlias([friendId UTF8String], alias ? [alias UTF8String] : "", new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getFriendExtra" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *friendId = dict[@"friendId"];
      std::string extra = mars::stn::MessageDB::Instance()->GetFriendExtra([friendId UTF8String]);
      result([NSString stringWithUTF8String:extra.c_str()]);
  } else if([@"isBlackListed" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *userId = dict[@"userId"];
      result(@(mars::stn::MessageDB::Instance()->isBlackListed([userId UTF8String])));
  } else if([@"getBlackList" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      BOOL refresh = dict[@"refresh"];
      NSMutableArray *ret = [[NSMutableArray alloc] init];
      std::list<std::string> friendList = mars::stn::MessageDB::Instance()->getBlackList(refresh);
      for (std::list<std::string>::iterator it = friendList.begin(); it != friendList.end(); it++) {
          [ret addObject:[NSString stringWithUTF8String:(*it).c_str()]];
      }
      result(ret);
  } else if([@"setBlackList" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *userId = dict[@"userId"];
      BOOL isBlackListed = [dict[@"isBlackListed"] boolValue];
      int requestId = [dict[@"requestId"] intValue];
      
      mars::stn::blackListRequest([userId UTF8String], isBlackListed, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getGroupMembers" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *groupId = dict[@"groupId"];
      BOOL refresh = [dict[@"refresh"] boolValue];
      
      std::list<mars::stn::TGroupMember> tmembers = mars::stn::MessageDB::Instance()->GetGroupMembers([groupId UTF8String], refresh);
      
      result(convertProtoGroupMembers(tmembers));
  } else if([@"getGroupMembersByTypes" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *groupId = dict[@"groupId"];
      int memberType = [dict[@"memberType"] intValue];
      
      std::list<mars::stn::TGroupMember> tmembers = mars::stn::MessageDB::Instance()->GetGroupMembersByType([groupId UTF8String], (int)memberType);
      
      result(convertProtoGroupMembers(tmembers));
  } else if([@"getGroupMembersAsync" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *groupId = dict[@"groupId"];
      int requestId = [dict[@"requestId"] intValue];
      BOOL refresh = [dict[@"refresh"] boolValue];
      
      mars::stn::MessageDB::Instance()->GetGroupMembers([groupId UTF8String], refresh, new IMGetGroupMembersCallback(^(const std::list<mars::stn::TGroupMember> &groupMemberList) {
          [self.channel invokeMethod:@"getGroupMembersAsyncCallback" arguments:@{@"requestId":@(requestId), @"members":convertProtoGroupMembers(groupMemberList), @"groupId":groupId}];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getGroupInfo" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *groupId = dict[@"groupId"];
      BOOL refresh = [dict[@"refresh"] boolValue];
      
      mars::stn::TGroupInfo tgi = mars::stn::MessageDB::Instance()->GetGroupInfo([groupId UTF8String], refresh);
      result(convertProtoGroupInfo(tgi));
  } else if([@"getGroupInfoAsync" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *groupId = dict[@"groupId"];
      int requestId = [dict[@"requestId"] intValue];
      BOOL refresh = [dict[@"refresh"] boolValue];
      mars::stn::MessageDB::Instance()->GetGroupInfo([groupId UTF8String], refresh, new IMGetOneGroupInfoCallback(^(const mars::stn::TGroupInfo &tgi){
          [self.channel invokeMethod:@"getGroupInfoAsyncCallback" arguments:@{@"requestId":@(requestId), @"groupInfo":convertProtoGroupInfo(tgi)}];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getGroupMember" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *groupId = dict[@"groupId"];
      NSString *memberId = dict[@"memberId"];
      
      mars::stn::TGroupMember tmember = mars::stn::MessageDB::Instance()->GetGroupMember([groupId UTF8String], [memberId UTF8String]);
      result(convertProtoGroupMember(tmember));
  } else if([@"createGroup" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *groupId = dict[@"groupId"];
      NSString *groupName = dict[@"groupName"];
      NSString *groupPortrait = dict[@"groupPortrait"];
      int groupType = [dict[@"type"] intValue];
      NSArray *groupMembers = dict[@"groupMembers"];
      NSArray *notifyLines = dict[@"notifyLines"];
      NSDictionary *notifyContent = dict[@"notifyContent"];
                     
      std::list<std::string> memberList;
      for (NSString *member in groupMembers) {
          memberList.push_back([member UTF8String]);
      }
      mars::stn::TMessageContent tcontent;
      fillMessageContent(tcontent, notifyContent);
      
      std::list<int> lines;
      if([notifyLines isKindOfClass:NSNull.class] || !notifyLines.count) {
          lines.push_back(0);
      } else {
          for (NSNumber *number in notifyLines) {
              lines.push_back([number intValue]);
          }
      }
      mars::stn::createGroup(groupId == nil ? "" : [groupId UTF8String], groupName == nil ? "" : [groupName UTF8String], groupPortrait == nil ? "" : [groupPortrait UTF8String], groupType, memberList, lines, tcontent, new IMCreateGroupCallback(^(NSString *groupId) {
          [self callbackOperationStringSuccess:requestId strValue:groupId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"addGroupMembers" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *groupId = dict[@"groupId"];
      NSArray *members = dict[@"groupMembers"];
      NSArray *notifyLines = dict[@"notifyLines"];
      NSDictionary *notifyContent = dict[@"notifyContent"];
      
      std::list<std::string> memberList;
      for (NSString *member in members) {
          memberList.push_back([member UTF8String]);
      }

      mars::stn::TMessageContent tcontent;
      fillMessageContent(tcontent, notifyContent);
      
      std::list<int> lines;
      for (NSNumber *number in notifyLines) {
          lines.push_back([number intValue]);
      }
      
      mars::stn::addMembers([groupId UTF8String], memberList, lines, tcontent, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"kickoffGroupMembers" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *groupId = dict[@"groupId"];
      NSArray *members = dict[@"groupMembers"];
      NSArray *notifyLines = dict[@"notifyLines"];
      NSDictionary *notifyContent = dict[@"notifyContent"];
      
      std::list<std::string> memberList;
      for (NSString *member in members) {
          memberList.push_back([member UTF8String]);
      }

      mars::stn::TMessageContent tcontent;
      fillMessageContent(tcontent, notifyContent);
      
      std::list<int> lines;
      for (NSNumber *number in notifyLines) {
          lines.push_back([number intValue]);
      }
      
      mars::stn::kickoffMembers([groupId UTF8String], memberList, lines, tcontent, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"quitGroup" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *groupId = dict[@"groupId"];
      NSArray *notifyLines = dict[@"notifyLines"];
      NSDictionary *notifyContent = dict[@"notifyContent"];
      
      mars::stn::TMessageContent tcontent;
      fillMessageContent(tcontent, notifyContent);
      
      std::list<int> lines;
      for (NSNumber *number in notifyLines) {
          lines.push_back([number intValue]);
      }
      
      mars::stn::quitGroup([groupId UTF8String], lines, tcontent, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"dismissGroup" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *groupId = dict[@"groupId"];
      NSArray *notifyLines = dict[@"notifyLines"];
      NSDictionary *notifyContent = dict[@"notifyContent"];
      
      mars::stn::TMessageContent tcontent;
      fillMessageContent(tcontent, notifyContent);
      
      std::list<int> lines;
      for (NSNumber *number in notifyLines) {
          lines.push_back([number intValue]);
      }
      
      mars::stn::dismissGroup([groupId UTF8String], lines, tcontent, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"modifyGroupInfo" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *groupId = dict[@"groupId"];
      int modifyType = [dict[@"modifyType"] intValue];
      NSString *newValue = dict[@"value"];
      NSArray *notifyLines = dict[@"notifyLines"];
      NSDictionary *notifyContent = dict[@"notifyContent"];
      
      
      mars::stn::TMessageContent tcontent;
      fillMessageContent(tcontent, notifyContent);
      
      std::list<int> lines;
      for (NSNumber *number in notifyLines) {
          lines.push_back([number intValue]);
      }
      
      mars::stn::modifyGroupInfo([groupId UTF8String], modifyType, [newValue UTF8String], lines, tcontent, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"modifyGroupAlias" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *groupId = dict[@"groupId"];
      NSString *newAlias = dict[@"newAlias"];
      NSArray *notifyLines = dict[@"notifyLines"];
      NSDictionary *notifyContent = dict[@"notifyContent"];
      
      
      mars::stn::TMessageContent tcontent;
      fillMessageContent(tcontent, notifyContent);
      
      std::list<int> lines;
      for (NSNumber *number in notifyLines) {
          lines.push_back([number intValue]);
      }
      
      mars::stn::modifyGroupAlias([groupId UTF8String], [newAlias UTF8String], lines, tcontent, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"modifyGroupMemberAlias" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *groupId = dict[@"groupId"];
      NSString *memberId = dict[@"memberId"];
      NSString *newAlias = dict[@"newAlias"];
      NSArray *notifyLines = dict[@"notifyLines"];
      NSDictionary *notifyContent = dict[@"notifyContent"];
      
      mars::stn::TMessageContent tcontent;
      fillMessageContent(tcontent, notifyContent);
      
      std::list<int> lines;
      for (NSNumber *number in notifyLines) {
          lines.push_back([number intValue]);
      }
      
      
      mars::stn::modifyGroupMemberAlias([groupId UTF8String], [memberId UTF8String], [newAlias UTF8String], lines, tcontent, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"transferGroup" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *groupId = dict[@"groupId"];
      NSString *newOwner = dict[@"newOwner"];
      NSArray *notifyLines = dict[@"notifyLines"];
      NSDictionary *notifyContent = dict[@"notifyContent"];
      
      mars::stn::TMessageContent tcontent;
      fillMessageContent(tcontent, notifyContent);
      
      std::list<int> lines;
      for (NSNumber *number in notifyLines) {
          lines.push_back([number intValue]);
      }
      
      mars::stn::transferGroup([groupId UTF8String], [newOwner UTF8String], lines, tcontent, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"setGroupManager" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *groupId = dict[@"groupId"];
      BOOL isSet = [dict[@"isSet"] boolValue];
      NSArray *memberIds = dict[@"memberIds"];
      NSArray *notifyLines = dict[@"notifyLines"];
      NSDictionary *notifyContent = dict[@"notifyContent"];
      
      mars::stn::TMessageContent tcontent;
      fillMessageContent(tcontent, notifyContent);
      
      std::list<int> lines;
      for (NSNumber *number in notifyLines) {
          lines.push_back([number intValue]);
      }
      
      std::list<std::string> memberList;
      for (NSString *member in memberIds) {
          memberList.push_back([member UTF8String]);
      }
      
      mars::stn::SetGroupManager([groupId UTF8String], memberList, isSet, lines, tcontent, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"muteGroupMember" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *groupId = dict[@"groupId"];
      BOOL isSet = [dict[@"isSet"] boolValue];
      NSArray *memberIds = dict[@"memberIds"];
      NSArray *notifyLines = dict[@"notifyLines"];
      NSDictionary *notifyContent = dict[@"notifyContent"];
      
      mars::stn::TMessageContent tcontent;
      fillMessageContent(tcontent, notifyContent);
      
      std::list<int> lines;
      for (NSNumber *number in notifyLines) {
          lines.push_back([number intValue]);
      }
      
      std::list<std::string> memberList;
      for (NSString *member in memberIds) {
          memberList.push_back([member UTF8String]);
      }
      
      mars::stn::MuteOrAllowGroupMember([groupId UTF8String], memberList, isSet, false, lines, tcontent, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"allowGroupMember" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *groupId = dict[@"groupId"];
      BOOL isSet = [dict[@"isSet"] boolValue];
      NSArray *memberIds = dict[@"memberIds"];
      NSArray *notifyLines = dict[@"notifyLines"];
      NSDictionary *notifyContent = dict[@"notifyContent"];
      
      mars::stn::TMessageContent tcontent;
      fillMessageContent(tcontent, notifyContent);
      
      std::list<int> lines;
      for (NSNumber *number in notifyLines) {
          lines.push_back([number intValue]);
      }
      
      std::list<std::string> memberList;
      for (NSString *member in memberIds) {
          memberList.push_back([member UTF8String]);
      }
      
      mars::stn::MuteOrAllowGroupMember([groupId UTF8String], memberList, isSet, true, lines, tcontent, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getFavGroups" isEqualToString:call.method]) {
      NSDictionary *favUserDict = [self getUserSettings:6];
      NSMutableArray *ids = [[NSMutableArray alloc] init];
      [favUserDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
          if ([obj isEqualToString:@"1"]) {
              [ids addObject:key];
          }
      }];
      result(ids);
  } else if([@"isFavGroup" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *groupId = dict[@"groupId"];
      
      NSString *strValue = [self getUserSetting:6 key:groupId];
      if ([strValue isEqualToString:@"1"]) {
          result(@(YES));
      } else {
          result(@(NO));
      }
  } else if([@"setFavGroup" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *groupId = dict[@"groupId"];
      BOOL isFav = [dict[@"isFav"] boolValue];
      
      [self setUserSetting:6 key:groupId value:isFav? @"1" : @"0" requestId:requestId];
      result(nil);
  } else if([@"getUserSetting" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int scope = [dict[@"scope"] intValue];
      NSString *key = dict[@"key"];
      
      result([self getUserSetting:scope key:key]);
  } else if([@"getUserSettings" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int scope = [dict[@"scope"] intValue];
      
      result([self getUserSettings:scope]);
  } else if([@"setUserSetting" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      NSString *key = dict[@"key"];
      NSString *value = dict[@"value"];
      int scope = [dict[@"scope"] intValue];
      
      [self setUserSetting:scope key:key value:value requestId:requestId];
      result(nil);
  } else if([@"modifyMyInfo" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSDictionary<NSNumber *, NSString *> *values = dict[@"values"];
      int requestId = [dict[@"requestId"] intValue];
      
      std::list<std::pair<int, std::string>> infos;
      for(NSNumber *key in values.allKeys) {
          infos.push_back(std::pair<int, std::string>([key intValue], [values[key] UTF8String]));
      }
      mars::stn::modifyMyInfo(infos, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"isGlobalSlient" isEqualToString:call.method]) {
      NSString *strValue = [self getUserSetting:2 key:@""];
      result(@([strValue isEqualToString:@"1"]));
  } else if([@"setGlobalSlient" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      bool isSilent = [dict[@"isSilent"] boolValue];
      
      [self setUserSetting:2 key:@"" value:isSilent?@"1":@"0" requestId:requestId];
      result(nil);
  } else if([@"getNoDisturbingTimes" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      
      NSString *strValue = [self getUserSetting:17 key:@""];
      if (strValue.length) {
          NSArray<NSString *> *arrs = [strValue componentsSeparatedByString:@"|"];
          if (arrs.count == 2) {
              int startMins = [arrs[0] intValue];
              int endMins = [arrs[1] intValue];
              [self.channel invokeMethod:@"onOperationIntPairSuccess" arguments:@{@"requestId":@(requestId), @"first":@(startMins), @"second":@(endMins)}];
          } else {
              [self callbackOperationFailure:requestId errorCode:-1];
          }
      } else {
          [self callbackOperationFailure:requestId errorCode:-1];
      }
      result(nil);
  } else if([@"setNoDisturbingTimes" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      int startMins = [dict[@"startMins"] intValue];
      int endMins = [dict[@"endMins"] intValue];
      
      [self setUserSetting:17 key:@"" value:[NSString stringWithFormat:@"%d|%d", startMins, endMins] requestId:requestId];
      result(nil);
  } else if([@"clearNoDisturbingTimes" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      
      [self setUserSetting:17 key:@"" value:@"" requestId:requestId];
      result(nil);
  } else if([@"isHiddenNotificationDetail" isEqualToString:call.method]) {
      NSString *strValue = [self getUserSetting:4 key:@""];
      result(@([strValue isEqualToString:@"1"]));
  } else if([@"setHiddenNotificationDetail" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      bool isHidden = [dict[@"isHidden"] boolValue];
      
      [self setUserSetting:4 key:@"" value:isHidden?@"1":@"0" requestId:requestId];
      result(nil);
  } else if([@"isHiddenGroupMemberName" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *groupId = dict[@"groupId"];
      
      NSString *strValue = [self getUserSetting:5 key:groupId];
      result(@([strValue isEqualToString:@"1"]));
  } else if([@"setHiddenGroupMemberName" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *groupId = dict[@"groupId"];
      bool isHidden = [dict[@"isHidden"] boolValue];
      int requestId = [dict[@"requestId"] intValue];
      
      [self setUserSetting:5 key:groupId value:isHidden?@"1":@"0" requestId:requestId];
      result(nil);
  } else if([@"isUserEnableReceipt" isEqualToString:call.method]) {
      NSString *strValue = [self getUserSetting:13 key:@""];
      result(@(![strValue isEqualToString:@"1"]));
  } else if([@"setUserEnableReceipt" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      bool isEnable = [dict[@"isEnable"] boolValue];
      int requestId = [dict[@"requestId"] intValue];
      
      [self setUserSetting:13 key:@"" value:isEnable?@"0":@"1"  requestId:requestId];
      result(nil);
  } else if([@"getFavUsers" isEqualToString:call.method]) {
      NSDictionary *favUserDict = [self getUserSettings:14];
      NSMutableArray *ids = [[NSMutableArray alloc] init];
      [favUserDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
          if ([obj isEqualToString:@"1"]) {
              [ids addObject:key];
          }
      }];
      result(ids);
  } else if([@"isFavUser" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *userId = dict[@"userId"];
      NSString *strValue = [self getUserSetting:14 key:userId];
      if ([strValue isEqualToString:@"1"]) {
          result(@(YES));
      } else {
          result(@(NO));
      }
  } else if([@"setFavUser" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *userId = dict[@"userId"];
      BOOL isFav = [dict[@"isFav"] boolValue];
      int requestId = [dict[@"requestId"] intValue];
      
      [self setUserSetting:14 key:userId value:isFav? @"1" : @"0" requestId:requestId];
      result(nil);
  } else if([@"joinChatroom" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *chatroomId = dict[@"chatroomId"];
      int requestId = [dict[@"requestId"] intValue];
      
      mars::stn::joinChatroom([chatroomId UTF8String], new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"quitChatroom" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *chatroomId = dict[@"chatroomId"];
      int requestId = [dict[@"requestId"] intValue];
      
      mars::stn::quitChatroom([chatroomId UTF8String], new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getChatroomInfo" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *chatroomId = dict[@"chatroomId"];
      int requestId = [dict[@"requestId"] intValue];
      long long updateDt = [dict[@"updateDt"] longLongValue];
      
      mars::stn::getChatroomInfo([chatroomId UTF8String], updateDt, new IMGetChatroomInfoCallback(^(const mars::stn::TChatroomInfo &info) {
          [self.channel invokeMethod:@"onGetChatroomInfoResult" arguments:@{@"requestId":@(requestId), @"chatroomInfo":convertProtoChatroomInfo(info)}];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getChatroomMemberInfo" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *chatroomId = dict[@"chatroomId"];
      int requestId = [dict[@"requestId"] intValue];
      int maxCount = [dict[@"maxCount"] intValue];
      
      if (maxCount <= 0) {
          maxCount = 30;
      }
      mars::stn::getChatroomMemberInfo([chatroomId UTF8String], maxCount, new IMGetChatroomMemberInfoCallback(^(const mars::stn::TChatroomMemberInfo &info) {
          [self.channel invokeMethod:@"onGetChatroomMemberInfoResult" arguments:@{@"requestId":@(requestId), @"chatroomMemberInfo":convertProtoChatroomMemberInfo(info)}];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"createChannel" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *channelName = dict[@"channelName"];
      NSString *channelPortrait = dict[@"channelPortrait"];
      NSString *desc = dict[@"desc"];
      NSString *extra = dict[@"extra"];
      int status = [dict[@"status"] intValue];
      int requestId = [dict[@"requestId"] intValue];
      
      if (!extra) {
          extra = @"";
      }
      mars::stn::createChannel("", [channelName UTF8String], [channelPortrait UTF8String], status, [desc UTF8String], [extra UTF8String], "", "", new IMCreateChannelCallback(^(const mars::stn::TChannelInfo &channelInfo) {
          [self.channel invokeMethod:@"onCreateChannelSuccess" arguments:@{@"requestId":@(requestId), @"channelInfo":convertProtoChannelInfo(channelInfo)}];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getChannelInfo" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *channelId = dict[@"channelId"];
      BOOL refresh = dict[@"refresh"];
      
      mars::stn::TChannelInfo tgi = mars::stn::MessageDB::Instance()->GetChannelInfo([channelId UTF8String], refresh);
      
      result(convertProtoChannelInfo(tgi));
  } else if([@"modifyChannelInfo" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *channelId = dict[@"channelId"];
      int type = [dict[@"type"] intValue];
      NSString *newValue = dict[@"newValue"];
      int requestId = [dict[@"requestId"] intValue];
      
      mars::stn::modifyChannelInfo([channelId UTF8String], (int)type, [newValue UTF8String], new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"searchChannel" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *keyword = dict[@"keyword"];
      int requestId = [dict[@"requestId"] intValue];
      
      mars::stn::searchChannel([keyword UTF8String], YES, new IMSearchChannelCallback(^(const std::list<mars::stn::TChannelInfo> &channels) {
          [self.channel invokeMethod:@"onSearchChannelResult" arguments:@{@"requestId":@(requestId), @"channelInfos":convertProtoChannelInfoList(channels)}];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"isListenedChannel" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *channelId = dict[@"channelId"];
      
      if([@"1" isEqualToString:[self getUserSetting:9 key:channelId]]) {
          result(@(YES));
      } else {
          result(@(NO));
      }
  } else if([@"listenChannel" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *channelId = dict[@"channelId"];
      BOOL listen = [dict[@"listen"] boolValue];
      int requestId = [dict[@"requestId"] intValue];
      
      mars::stn::listenChannel([channelId UTF8String], listen, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getListenedChannels" isEqualToString:call.method]) {
      NSDictionary *myChannelDict = [self getUserSettings:9];
      NSMutableArray *ids = [[NSMutableArray alloc] init];
      [myChannelDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
          if ([obj isEqualToString:@"1"]) {
              [ids addObject:key];
          }
      }];
      result(ids);
  } else if([@"destoryChannel" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *channelId = dict[@"channelId"];
      int requestId = [dict[@"requestId"] intValue];
      
      mars::stn::destoryChannel([channelId UTF8String], new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getOnlineInfos" isEqualToString:call.method]) {
      NSString *pcOnline = [self getUserSetting:10 key:@"PC"];
      NSString *webOnline = [self getUserSetting:10 key:@"Web"];
      NSString *wxOnline = [self getUserSetting:10 key:@"WX"];
      
      NSMutableArray *output = [[NSMutableArray alloc] init];
      if (pcOnline.length) {
          [output addObject:[self pcOnlineInfo:pcOnline withType:0]];
      }
      if (webOnline.length) {
          [output addObject:[self pcOnlineInfo:webOnline withType:1]];
      }
      if (wxOnline.length) {
          [output addObject:[self pcOnlineInfo:wxOnline withType:2]];
      }
      result(output);
  } else if([@"kickoffPCClient" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *pcClientId = dict[@"clientId"];
      int requestId = [dict[@"requestId"] intValue];
      
      mars::stn::KickoffPCClient([pcClientId UTF8String], new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"isMuteNotificationWhenPcOnline" isEqualToString:call.method]) {
      NSString *strValue = [self getUserSetting:15 key:@""];
      if ([strValue isEqualToString:@"1"]) {
          result(@(YES));
      } else {
          result(@(NO));
      }
  } else if([@"muteNotificationWhenPcOnline" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      BOOL isMute = [dict[@"isMute"] boolValue];
      int requestId = [dict[@"requestId"] intValue];
      
      [self setUserSetting:15 key:@"" value:isMute? @"1" : @"0" requestId:requestId];
      result(nil);
  } else if([@"getConversationFiles" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *userId = dict[@"userId"];
      NSDictionary *convDict = dict[@"conversation"];
      int requestId = [dict[@"requestId"] intValue];
      long long beforeMessageUid = [dict[@"beforeMessageUid"] longLongValue];
      int count = [dict[@"count"] intValue];
      
      mars::stn::TConversation conv;
      if (convDict) {
          conv.target = [convDict[@"target"] UTF8String];
          conv.line = [convDict[@"line"] intValue];
          conv.conversationType = [convDict[@"type"] intValue];
      }
      
      std::string fromUser = userId ? [userId UTF8String] : "";
      mars::stn::loadConversationFileRecords(conv, fromUser, beforeMessageUid, count, new IMLoadFileRecordCallback(^(const std::list<mars::stn::TFileRecord> &fileList) {
          [self.channel invokeMethod:@"onFilesResult" arguments:@{@"requestId":@(requestId), @"files":convertProtoFileRecords(fileList)}];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getMyFiles" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      int requestId = [dict[@"requestId"] intValue];
      long long beforeMessageUid = [dict[@"beforeMessageUid"] longLongValue];
      int count = [dict[@"count"] intValue];
      
      mars::stn::loadMyFileRecords(beforeMessageUid, count, new IMLoadFileRecordCallback(^(const std::list<mars::stn::TFileRecord> &fileList) {
          [self.channel invokeMethod:@"onFilesResult" arguments:@{@"requestId":@(requestId), @"files":convertProtoFileRecords(fileList)}];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"deleteFileRecord" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      long long messageUid = [dict[@"messageUid"] longLongValue];
      int requestId = [dict[@"requestId"] intValue];
      
      mars::stn::deleteFileRecords(messageUid, new IMGeneralOperationCallback(^(){
          [self callbackOperationVoidSuccess:requestId];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"searchFiles" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *keyword = dict[@"keyword"];
      NSString *userId = dict[@"userId"];
      NSDictionary *convDict = dict[@"conversation"];
      int requestId = [dict[@"requestId"] intValue];
      long long beforeMessageUid = [dict[@"beforeMessageUid"] longLongValue];
      int count = [dict[@"count"] intValue];
      
      mars::stn::TConversation conv;
      if (convDict) {
          conv.target = [convDict[@"target"] UTF8String];
          conv.line = [convDict[@"line"] intValue];
          conv.conversationType = [convDict[@"type"] intValue];
      }
      
      
      std::string fromUser = userId ? [userId UTF8String] : "";
      mars::stn::searchConversationFileRecords([keyword UTF8String], conv, fromUser, beforeMessageUid, count, new IMLoadFileRecordCallback(^(const std::list<mars::stn::TFileRecord> &fileList) {
          [self.channel invokeMethod:@"onFilesResult" arguments:@{@"requestId":@(requestId), @"files":convertProtoFileRecords(fileList)}];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"searchMyFiles" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *keyword = dict[@"keyword"];
      int requestId = [dict[@"requestId"] intValue];
      long long beforeMessageUid = [dict[@"beforeMessageUid"] longLongValue];
      int count = [dict[@"count"] intValue];
      mars::stn::searchMyFileRecords([keyword UTF8String], beforeMessageUid, count, new IMLoadFileRecordCallback(^(const std::list<mars::stn::TFileRecord> &fileList) {
          [self.channel invokeMethod:@"onFilesResult" arguments:@{@"requestId":@(requestId), @"files":convertProtoFileRecords(fileList)}];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getAuthorizedMediaUrl" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *mediaPath = dict[@"mediaPath"];
      int requestId = [dict[@"requestId"] intValue];
      long long messageUid = [dict[@"messageUid"] longLongValue];
      int mediaType = [dict[@"mediaType"] intValue];
      
      mars::stn::getAuthorizedMediaUrl(messageUid, (int)mediaType, [mediaPath UTF8String], new IMGeneralStringCallback(^(NSString *path) {
          [self callbackOperationStringSuccess:requestId strValue:path];
      }, ^(int errorCode) {
          [self callbackOperationFailure:requestId errorCode:errorCode];
      }));
      result(nil);
  } else if([@"getWavData" isEqualToString:call.method]) {
      NSDictionary *dict = (NSDictionary *)call.arguments;
      NSString *amrPath = dict[@"amrPath"];
      
      NSData *data;
      if ([@"mp3" isEqualToString:[amrPath pathExtension]]) {
           data = [NSData dataWithContentsOfFile:amrPath];
      } else {
          data = [[NSMutableData alloc] init];
          decode_amr([amrPath UTF8String], (NSMutableData*)data);
      }
      result([FlutterStandardTypedData typedDataWithBytes:data]);
  } else if([@"beginTransaction" isEqualToString:call.method]) {
      result(@(mars::stn::MessageDB::Instance()->BeginTransaction()));
  } else if([@"commitTransaction" isEqualToString:call.method]) {
      mars::stn::MessageDB::Instance()->CommitTransaction();
      result(nil);
  } else if([@"isCommercialServer" isEqualToString:call.method]) {
      result(@(mars::stn::IsCommercialServer() == true));
  } else if([@"isReceiptEnabled" isEqualToString:call.method]) {
      result(@(mars::stn::IsReceiptEnabled() == true));
  } else {
    result(FlutterMethodNotImplemented);
  }
}

-(void)initClient {
    if (!self.isInited) {
        self.isInited = YES;
        mars::app::SetCallback(mars::app::AppCallBack::Instance());
        mars::stn::setConnectionStatusCallback(new CSCB(self));
        mars::stn::setReceiveMessageCallback(new RPCB(self));
          mars::stn::setConferenceEventCallback(new CONFCB(self));
        mars::stn::setRefreshUserInfoCallback(new GUCB(self));
        mars::stn::setRefreshGroupInfoCallback(new GGCB(self));
          mars::stn::setRefreshGroupMemberCallback(new GGMCB(self));
        mars::stn::setRefreshChannelInfoCallback(new GCHCB(self));
        mars::stn::setRefreshFriendListCallback(new GFLCB(self));
          mars::stn::setRefreshFriendRequestCallback(new GFRCB(self));
        mars::stn::setRefreshSettingCallback(new GSCB(self));
        
        mars::baseevent::OnCreate();
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onAppSuspend)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onAppResume)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onAppTerminate)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
    }
}
- (void)connect:(NSString *)host userId:(NSString *)userId token:(NSString *)token result:(FlutterResult)result {
    if (self.logined) {
        for (int i = 0; i < 10; i++) {
            xerror2(TSF"Error: 使用错误，已经connect过了，不能再次connect。如果切换用户请先disconnect，再connect。请修正改错误");
        }
#if DEBUG
        exit(-1);
#else
        result(@(NO));
#endif
        
        return;
    }
    
    self.logined = YES;
    self.deviceTokenUploaded = NO;
    self.voipDeviceTokenUploaded = NO;
    
    mars::app::AppCallBack::Instance()->SetAccountUserName([self.userId UTF8String]);
    if(!mars::stn::setAuthInfo([self.userId cStringUsingEncoding:NSUTF8StringEncoding], [token cStringUsingEncoding:NSUTF8StringEncoding])) {
        result(@(NO));
        return;
    }
    [[WFCCNetworkStatus sharedInstance] Start:self];
    mars::baseevent::OnForeground(true);
    self.connectionStatus = kConnectionStatusConnecting;
    
    bool newDB = mars::stn::Connect([host UTF8String]);
    result(@(newDB));
}

- (void)startBackgroundTask {
    if (!_logined) {
        return;
    }
    
    if (_bgTaskId !=  UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:_bgTaskId];
    }
    __weak typeof(self) ws = self;
    _bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if (ws.suspendTimer) {
            [ws.suspendTimer invalidate];
            ws.suspendTimer = nil;
        }
        
        if(ws.endBgTaskTimer) {
            [ws.endBgTaskTimer invalidate];
            ws.endBgTaskTimer = nil;
        }
        if(ws.forceConnectTimer) {
            [ws.forceConnectTimer invalidate];
            ws.forceConnectTimer = nil;
        }
        
        ws.bgTaskId = UIBackgroundTaskInvalid;
    }];
}

- (void)onAppSuspend {
    if (!_logined) {
        return;
    }
    
    mars::baseevent::OnForeground(false);
    
    self.backgroudRunTime = 0;
    [self startBackgroundTask];
    
    [self checkBackGroundTask];
}

- (void)checkBackGroundTask {
    if(_suspendTimer) {
        [_suspendTimer invalidate];
    }
    if(_endBgTaskTimer) {
        [_endBgTaskTimer invalidate];
        _endBgTaskTimer = nil;
    }
    
    NSTimeInterval timeInterval = 3;
    
    _suspendTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval
                                                     target:self
                                                   selector:@selector(suspend)
                                                   userInfo:nil
                                                    repeats:NO];

}
- (void)suspend {
  if(_bgTaskId != UIBackgroundTaskInvalid) {
      self.backgroudRunTime += 3;
      BOOL inCall = NO;
      Class cls = NSClassFromString(@"WFAVEngineKit");
      
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
      if (cls && [cls respondsToSelector:@selector(isCallActive)] && [cls performSelector:@selector(isCallActive)]) {
          inCall = YES;
      }
#pragma clang diagnostic pop
      
      if ((mars::stn::GetTaskCount() > 0 && self.backgroudRunTime < 60) || (inCall && self.backgroudRunTime < 1800)) {
          [self checkBackGroundTask];
      } else {
          mars::stn::ClearTasks();
          _endBgTaskTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                       target:self
                                                     selector:@selector(endBgTask)
                                                     userInfo:nil
                                                      repeats:NO];
      }
  }
}
- (void)endBgTask {
  if(_bgTaskId !=  UIBackgroundTaskInvalid) {
    [[UIApplication sharedApplication] endBackgroundTask:_bgTaskId];
    _bgTaskId =  UIBackgroundTaskInvalid;
  }
  
  if (_suspendTimer) {
    [_suspendTimer invalidate];
    _suspendTimer = nil;
  }
  
  if(_endBgTaskTimer) {
    [_endBgTaskTimer invalidate];
    _endBgTaskTimer = nil;
  }
    
    if (_forceConnectTimer) {
        [_forceConnectTimer invalidate];
        _forceConnectTimer = nil;
    }
    
    self.backgroudRunTime = 0;
}

- (void)onAppResume {
  if (!_logined) {
    return;
  }
    
  mars::baseevent::OnForeground(true);
  mars::stn::MakesureLonglinkConnected();
  [self endBgTask];
}

- (void)onAppTerminate {
    mars::stn::AppWillTerminate();
}


- (void)disconnect:(BOOL)disablePush clearSession:(BOOL)clearSession {
    if(!_logined) {
        return;
    }
    
    _logined = NO;
    self.userId = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.connectionStatus = kConnectionStatusLogout;
    });
    [[WFCCNetworkStatus sharedInstance] Stop];
    int flag = 0;
    if (clearSession) {
        flag = 8;
    } else if(disablePush) {
        flag = 1;
    }
    
  if (mars::stn::getConnectionStatus() != mars::stn::kConnectionStatusConnected && mars::stn::getConnectionStatus() != mars::stn::kConnectionStatusReceiving) {
    mars::stn::Disconnect(flag);
    [self destroyMars];
  } else {
    mars::stn::Disconnect(flag);
  }
}

- (void)destroyMars {
  [[WFCCNetworkStatus sharedInstance] Stop];
    mars::baseevent::OnDestroy();
}

+ (void)startLog {
    NSString* logPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/log"];
    
    // set do not backup for logpath
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    setxattr([logPath UTF8String], attrName, &attrValue, sizeof(attrValue), 0, 0);
    
    // init xlog
#if DEBUG
    xlogger_SetLevel(kLevelVerbose);
    appender_set_console_log(true);
#else
    xlogger_SetLevel(kLevelInfo);
    appender_set_console_log(false);
#endif
    appender_open(kAppednerAsync, [logPath UTF8String], "Test", NULL);
}

+ (void)stopLog {
    appender_close();
}

+ (NSArray<NSString *> *)getLogFilesPath {
    NSString* logPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/log"];
    
    NSFileManager *myFileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *myDirectoryEnumerator = [myFileManager enumeratorAtPath:logPath];

    BOOL isDir = NO;
    BOOL isExist = NO;

    NSMutableArray *output = [[NSMutableArray alloc] init];
    for (NSString *path in myDirectoryEnumerator.allObjects) {
        isExist = [myFileManager fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", logPath, path] isDirectory:&isDir];
        if (!isDir) {
            if ([path containsString:@"Test_"]) {
                [output addObject:[NSString stringWithFormat:@"%@/%@", logPath, path]];
            }
        }
    }

    return output;
}

- (void)getConversationInfos:(NSArray *)conversationTypes lines:(NSArray *)lines result:(FlutterResult)result {
    std::list<int> types;
    for (NSNumber *type in conversationTypes) {
        types.push_back([type intValue]);
    }
    
    std::list<int> ls;
    for (NSNumber *type in lines) {
        ls.push_back([type intValue]);
    }
    std::list<mars::stn::TConversation> convers = mars::stn::MessageDB::Instance()->GetConversationList(types, ls);
    NSMutableArray *ret = [[NSMutableArray alloc] init];
    for (std::list<mars::stn::TConversation>::iterator it = convers.begin(); it != convers.end(); it++) {
        NSMutableDictionary *info = convertProtoConversationInfo(*it);
        [ret addObject:info];
    }
    
    result(ret);
}

- (void)getConversationInfo:(NSDictionary *)conversation result:(FlutterResult)result {
    int type = [conversation[@"type"] intValue];
    NSString *target = conversation[@"target"];
    int line = [conversation[@"line"] intValue];
    
    mars::stn::TConversation tConv = mars::stn::MessageDB::Instance()->GetConversation(type, [target UTF8String], line);
    NSMutableDictionary *ret = convertProtoConversationInfo(tConv);
    result(ret);
}

- (void)searchConversation:(NSString *)keyword types:(NSArray *)conversationTypes lines:(NSArray *)lines result:(FlutterResult)result {
    if (!keyword.length) {
        result(nil);
        return;
    }
    
    std::list<int> types;
    for (NSNumber *type in conversationTypes) {
        types.push_back([type intValue]);
    }
    
    std::list<int> ls;
    for (NSNumber *type in lines) {
        ls.push_back([type intValue]);
    }
    
    std::list<mars::stn::TConversationSearchresult> tresult = mars::stn::MessageDB::Instance()->SearchConversations(types, ls, [keyword UTF8String], 50);
    NSMutableArray *results = [[NSMutableArray alloc] init];
    for (std::list<mars::stn::TConversationSearchresult>::iterator it = tresult.begin(); it != tresult.end(); it++) {
        [results addObject:convertProtoConversationSearchInfo(*it)];
    }
    
    result(results);
}

- (void)removeConversation:(NSDictionary *)conversation clearMessage:(BOOL)clearMessage {
    int type = [conversation[@"type"] intValue];
    NSString *target = conversation[@"target"];
    int line = [conversation[@"line"] intValue];
    
    mars::stn::MessageDB::Instance()->RemoveConversation(type, [target UTF8String], line, clearMessage);
}

- (void)set:(int)requestId Conversation:(NSDictionary *)conversation top:(BOOL)top {
    int type = [conversation[@"type"] intValue];
    NSString *target = conversation[@"target"];
    int line = [conversation[@"line"] intValue];
    
    [self set:requestId userSetting:mars::stn::kUserSettingConversationTop key:[NSString stringWithFormat:@"%d-%d-%@", type, line, target] value:top ? @"1" : @"0"];
}

- (void)set:(int)requestId Conversation:(NSDictionary *)conversation silent:(BOOL)silent {
    int type = [conversation[@"type"] intValue];
    NSString *target = conversation[@"target"];
    int line = [conversation[@"line"] intValue];
    
    [self set:requestId userSetting:mars::stn::kUserSettingConversationSilent key:[NSString stringWithFormat:@"%d-%d-%@", type, line, target] value:silent ? @"1" : @"0"];
}

- (void)set:(int)requestId Conversation:(NSDictionary *)conversation draft:(NSString *)draft {
    int type = [conversation[@"type"] intValue];
    NSString *target = conversation[@"target"];
    int line = [conversation[@"line"] intValue];
    
    mars::stn::MessageDB::Instance()->updateConversationDraft(type, [target UTF8String], line, draft ? [draft UTF8String] : "");
}

- (void)set:(int)requestId Conversation:(NSDictionary *)conversation timestamp:(long long)timestamp {
    int type = [conversation[@"type"] intValue];
    NSString *target = conversation[@"target"];
    int line = [conversation[@"line"] intValue];
    
    mars::stn::MessageDB::Instance()->updateConversationTimestamp(type, [target UTF8String], line, timestamp);
}

- (void)set:(int)requestId userSetting:(int)scope key:(NSString *)key value:(NSString *)value {
    mars::stn::modifyUserSetting(scope, [key UTF8String], [value UTF8String], new IMGeneralOperationCallback(^(){
        [self callbackOperationVoidSuccess:requestId];
    }, ^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }));
}

- (void)getFirstUnreadMessageIdOf:(NSDictionary *)conversation result:(FlutterResult)result {
    int type = [conversation[@"type"] intValue];
    NSString *target = conversation[@"target"];
    int line = [conversation[@"line"] intValue];
    
    long msgId = mars::stn::MessageDB::Instance()->GetConversationFirstUnreadMessageId(type, [target UTF8String], line);
    result(@(msgId));
}

- (void)getConversationUnreadCount:(NSDictionary *)conversation result:(FlutterResult)result {
    int type = [conversation[@"type"] intValue];
    NSString *target = conversation[@"target"];
    int line = [conversation[@"line"] intValue];
    
    mars::stn::TUnreadCount tcount = mars::stn::MessageDB::Instance()->GetUnreadCount(type, [target UTF8String], line);
    
    result(convertProtoUnreadCount(tcount));
}

- (void)getConversationsUnreadCount:(NSArray *)conversationTypes lines:(NSArray *)lines result:(FlutterResult)result {
    std::list<int> types;
    for (NSNumber *type in conversationTypes) {
        types.push_back([type intValue]);
    }
    
    std::list<int> ls;
    for (NSNumber *type in lines) {
        ls.push_back([type intValue]);
    }
    
    mars::stn::TUnreadCount tcount =  mars::stn::MessageDB::Instance()->GetUnreadCount(types, ls);
    result(convertProtoUnreadCount(tcount));
}

- (void)getConversationRead:(NSDictionary *)conversation result:(FlutterResult)result {
    int type = [conversation[@"type"] intValue];
    NSString *target = conversation[@"target"];
    int line = [conversation[@"line"] intValue];
    
    std::map<std::string, int64_t> reads = mars::stn::MessageDB::Instance()->GetConversationRead(type, [target UTF8String], line);
    NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
    
    for (std::map<std::string, int64_t>::iterator it = reads.begin(); it != reads.end(); ++it) {
        [ret setValue:@(it->second) forKey:[NSString stringWithUTF8String:it->first.c_str()]];
    }
    
    result(ret);
}

- (void)getMessageDelivery:(NSDictionary *)conversation result:(FlutterResult)result {
    int type = [conversation[@"type"] intValue];
    NSString *target = conversation[@"target"];
    
    std::map<std::string, int64_t> reads = mars::stn::MessageDB::Instance()->GetDelivery(type, [target UTF8String]);
    NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
    
    for (std::map<std::string, int64_t>::iterator it = reads.begin(); it != reads.end(); ++it) {
        [ret setValue:@(it->second) forKey:[NSString stringWithUTF8String:it->first.c_str()]];
    }
    
    result(ret);
}

- (void)getMessages:(NSDictionary *)conversation contentTypes:(NSArray<NSNumber *> *)contentTypes from:(NSUInteger)fromIndex count:(NSInteger)count withUser:(NSString *)user result:(FlutterResult)result {
    int type = [conversation[@"type"] intValue];
    NSString *target = conversation[@"target"];
    int line = [conversation[@"line"] intValue];
    
    std::list<int> types;
    for (NSNumber *num in contentTypes) {
        types.push_back(num.intValue);
    }
    bool direction = true;
    if (count < 0) {
        direction = false;
        count = -count;
    }
    
    std::list<mars::stn::TMessage> messages = mars::stn::MessageDB::Instance()->GetMessages(type, [target UTF8String], line, types, direction, (int)count, fromIndex, user ? [user UTF8String] : "");
    result(convertProtoMessageList(messages, YES));
}

- (void)getMessages:(NSDictionary *)conversation messageStatus:(NSArray<NSNumber *> *)messageStatus from:(NSUInteger)fromIndex count:(NSInteger)count withUser:(NSString *)user result:(FlutterResult)result {
    int type = [conversation[@"type"] intValue];
    NSString *target = conversation[@"target"];
    int line = [conversation[@"line"] intValue];
    
    std::list<int> types;
    for (NSNumber *num in messageStatus) {
        types.push_back(num.intValue);
    }
    bool direction = true;
    if (count < 0) {
        direction = false;
        count = -count;
    }
    
    std::list<mars::stn::TMessage> messages = mars::stn::MessageDB::Instance()->GetMessagesByMessageStatus(type, [target UTF8String], line, types, direction, (int)count, fromIndex, user ? [user UTF8String] : "");
    result(convertProtoMessageList(messages, YES));
}

- (void)getConversationsMessages:(NSArray *)conversationTypes lines:(NSArray *)lines contentTypes:(NSArray<NSNumber *> *)contentTypes from:(NSUInteger)fromIndex count:(NSInteger)count withUser:(NSString *)user result:(FlutterResult)result {
    std::list<int> convtypes;
    for (NSNumber *ct in conversationTypes) {
        convtypes.push_back([ct intValue]);
    }
    
    std::list<int> ls;
    for (NSNumber *type in lines) {
        ls.push_back([type intValue]);
    }
    
    
    std::list<int> types;
    for (NSNumber *num in contentTypes) {
        types.push_back(num.intValue);
    }
    bool direction = true;
    if (count < 0) {
        direction = false;
        count = -count;
    }
    
    std::list<mars::stn::TMessage> messages = mars::stn::MessageDB::Instance()->GetMessages(convtypes, ls, types, direction, (int)count, fromIndex, user ? [user UTF8String] : "");
    
    result(convertProtoMessageList(messages, YES));
}

- (void)getConversationsMessages:(NSArray *)conversationTypes lines:(NSArray *)lines messageStatus:(NSArray<NSNumber *> *)messageStatus from:(NSUInteger)fromIndex count:(NSInteger)count withUser:(NSString *)user result:(FlutterResult)result {
    std::list<int> convtypes;
    for (NSNumber *ct in conversationTypes) {
        convtypes.push_back([ct intValue]);
    }
    
    std::list<int> ls;
    for (NSNumber *type in lines) {
        ls.push_back([type intValue]);
    }
    
    std::list<int> status;
    for (NSNumber *num in messageStatus) {
        status.push_back(num.intValue);
    }

    bool direction = true;
    if (count < 0) {
        direction = false;
        count = -count;
    }
    
    std::list<mars::stn::TMessage> messages = mars::stn::MessageDB::Instance()->GetMessagesByMessageStatus(convtypes, ls, status, direction, (int)count, fromIndex, user ? [user UTF8String] : "");
    
    result(convertProtoMessageList(messages, YES));
}

- (void)getRemoteMessages:(NSDictionary *)conversation
                   before:(long long)beforeMessageUid
                    count:(NSUInteger)count
                  ofRequest:(int)requestId {
    mars::stn::TConversation conv;
    conv.conversationType = [conversation[@"type"] intValue];
    conv.target = [conversation[@"target"] UTF8String];
    conv.line = [conversation[@"line"] intValue];
    
    mars::stn::loadRemoteMessages(conv, beforeMessageUid, (int)count, new IMLoadRemoteMessagesCallback(^(const std::list<mars::stn::TMessage> &messageList) {
        [self.channel invokeMethod:@"onMessagesCallback" arguments:@{@"requestId":@(requestId), @"messages":convertProtoMessageList(messageList, NO)}];
    }, ^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }));
}

- (void)sendMessage:(int)requestId conversation:(NSDictionary *)convDict content:(NSDictionary *)contDict toUsers:(NSArray<NSString *> *)toUsers expireDuration:(int)expireDuration result:(FlutterResult)result {
    
    mars::stn::TMessage tmsg;
    if (toUsers.count) {
        for (NSString *obj in toUsers) {
            tmsg.to.push_back([obj UTF8String]);
        }
    }
    
    fillTMessage(tmsg, convDict, contDict);
    tmsg.from = mars::app::GetAccountUserName();
    tmsg.status = mars::stn::Message_Status_Sending;
    
    long messageId = mars::stn::sendMessage(tmsg, new IMSendMessageCallback(requestId, ^(long long messageUid, long long timestamp) {
        [self.channel invokeMethod:@"onSendMessageSuccess" arguments:@{@"requestId":@(requestId), @"messageUid":@(messageUid), @"timestamp":@(timestamp)}];
    },^(long uploaded, long total) {
        [self.channel invokeMethod:@"onSendMediaMessageProgress" arguments:@{@"requestId":@(requestId), @"uploaded":@(uploaded), @"total":@(total)}];
    },^(NSString *remoteUrl){
        [self.channel invokeMethod:@"onSendMediaMessageUploaded" arguments:@{@"requestId":@(requestId), @"remoteUrl":remoteUrl}];
    },^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }), expireDuration);
    
    tmsg.messageId = messageId;
    
    NSMutableDictionary *msg = convertProtoMessage(&tmsg);
    
    result(msg);
}

- (NSString *)getUserSetting:(int)scope key:(NSString *)key {
    if (!key) {
        key = @"";
    }
    std::string str = mars::stn::MessageDB::Instance()->GetUserSetting((int)scope, [key UTF8String]);
    return [NSString stringWithUTF8String:str.c_str()];
}

- (NSMutableDictionary *)getUserSettings:(int)scope {
    std::map<std::string, std::string> settings = mars::stn::MessageDB::Instance()->GetUserSettings((int)scope);
    NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
    for (std::map<std::string, std::string>::iterator it = settings.begin() ; it != settings.end(); it++) {
        NSString *key = [NSString stringWithUTF8String:it->first.c_str()];
        NSString *value = [NSString stringWithUTF8String:it->second.c_str()];
        [ret setObject:value forKey:key];
    }
    return ret;
}

- (void)setUserSetting:(int)scope key:(NSString *)key value:(NSString *)value requestId:(int)requestId {
    if (!key) {
        key = @"";
    }
    
    mars::stn::modifyUserSetting((int)scope, [key UTF8String], [value UTF8String], new IMGeneralOperationCallback(^(){
        [self callbackOperationVoidSuccess:requestId];
    }, ^(int errorCode) {
        [self callbackOperationFailure:requestId errorCode:errorCode];
    }));
}

- (NSDictionary *)pcOnlineInfo:(NSString *)strInfo withType:(int)type {
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    info[@"type"] = @(type);
    if (strInfo.length) {
        info[@"isOnline"] = @(YES);
        NSArray<NSString *> *parts = [strInfo componentsSeparatedByString:@"|"];
        if (parts.count >= 4) {
            info[@"timestamp"] = @([parts[0] longLongValue]);
            info[@"platform"] = @([parts[1] intValue]);
            info[@"clientId"] = parts[2];
            info[@"clientName"] = parts[3];
        }
    } else {
        info[@"isOnline"] = @(NO);
    }
    
    return info;
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

#pragma mark - setter
-(void)setConnectionStatus:(ConnectionStatus)connctionStatus {
    if (_connectionStatus != connctionStatus) {
        _connectionStatus = connctionStatus;
        [self.channel invokeMethod:@"onConnectionStatusChanged" arguments:@(connctionStatus)];
    }
}
#pragma mark - delegates
- (void)onRecallMessage:(long long)messageUid {
    [self.channel invokeMethod:@"onRecallMessage" arguments:@{@"messageUid":@(messageUid)}];
}

- (void)onDeleteMessage:(long long)messageUid {
    [self.channel invokeMethod:@"onDeleteMessage" arguments:@{@"messageUid":@(messageUid)}];
}

- (void)onReceiveMessage:(NSMutableArray<NSMutableDictionary *> *)messages hasMore:(BOOL)hasMore {
    [self.channel invokeMethod:@"onReceiveMessage" arguments:@{@"messages":messages, @"hasMore":@(hasMore)}];
}

- (void)onMessageReaded:(NSMutableArray<NSMutableDictionary *> *)readeds {
    [self.channel invokeMethod:@"onMessageReaded" arguments:@{@"readeds":readeds}];
}

- (void)onMessageDelivered:(NSMutableDictionary *)delivereds {
    [self.channel invokeMethod:@"onMessageDelivered" arguments:delivereds];
}

- (void)onConferenceEvent:(NSString *)event {
    
}

- (void)onConnectionStatusChanged:(ConnectionStatus)status {
    if (!_logined || kConnectionStatusRejected == status) {
      dispatch_async(dispatch_get_global_queue(0, DISPATCH_QUEUE_PRIORITY_DEFAULT), ^{
        [self disconnect:YES clearSession:YES];
      });
      return;
    }
      if((int)status == (int)mars::stn::kConnectionStatusServerDown) {
          status = kConnectionStatusUnconnected;
      }
    dispatch_async(dispatch_get_main_queue(), ^{
      self.connectionStatus = status;
      if (status == kConnectionStatusConnected) {
          if (self.deviceToken.length && !self.deviceTokenUploaded) {
              [self setDeviceToken:self.deviceToken];
          }
          
          if (self.voipDeviceToken.length && !self.voipDeviceTokenUploaded) {
              [self setVoipDeviceToken:self.voipDeviceToken];
          }
      }
    });
}

- (void)onUserInfoUpdated:(NSMutableArray<NSMutableDictionary *> *)updatedUserInfos {
    [self.channel invokeMethod:@"onUserInfoUpdated" arguments:@{@"users":updatedUserInfos}];
}

- (void)onGroupInfoUpdated:(NSMutableArray<NSMutableDictionary *> *)updatedGroupInfos {
    [self.channel invokeMethod:@"onGroupInfoUpdated" arguments:@{@"groups":updatedGroupInfos}];
}

- (void)onFriendListUpdated:(NSMutableArray<NSString *> *)friendList {
    [self.channel invokeMethod:@"onFriendListUpdated" arguments:@{@"friends":friendList}];
}

- (void)onFriendRequestsUpdated:(NSMutableArray<NSString *> *)newFriendRequests {
    [self.channel invokeMethod:@"onFriendRequestsUpdated" arguments:@{@"requests":newFriendRequests}];
}

- (void)onSettingUpdated {
    [self.channel invokeMethod:@"onSettingUpdated" arguments:nil];
}

- (void)onChannelInfoUpdated:(NSMutableArray<NSMutableDictionary *> *)updatedChannelInfos {
    [self.channel invokeMethod:@"onChannelInfoUpdated" arguments:@{@"channels":updatedChannelInfos}];
}

- (void)onGroupMemberUpdated:(NSString *)groupId members:(NSMutableArray<NSMutableDictionary *> *)updatedGroupMembers {
    [self.channel invokeMethod:@"onGroupMemberUpdated" arguments:@{@"groupId":groupId, @"members":updatedGroupMembers}];
}
#pragma mark - WFCCNetworkStatusDelegate
-(void) ReachabilityChange:(UInt32)uiFlags {
    if ((uiFlags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
        mars::baseevent::OnNetworkChange();
    }
}


@end
