
import 'package:event_bus/event_bus.dart';
import 'package:flutter/services.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/notification/call_add_participants_notificiation_content.dart';
import 'package:imclient/model/friend.dart';
import 'package:imclient/model/user_online_state.dart';

import 'imclient_method_channel.dart';
import 'message/card_message_content.dart';
import 'message/composite_message_content.dart';
import 'message/file_message_content.dart';
import 'message/image_message_content.dart';
import 'message/link_message_content.dart';
import 'message/location_message_content.dart';
import 'message/message.dart';
import 'message/message_content.dart';
import 'message/notification/delete_message_content.dart';
import 'message/notification/friend_added_message_content.dart';
import 'message/notification/friend_greeting_message_content.dart';
import 'message/notification/group/add_group_member_notification_content.dart';
import 'message/notification/group/change_group_name_notification_content.dart';
import 'message/notification/group/change_group_portrait_notification_content.dart';
import 'message/notification/group/create_group_notification_content.dart';
import 'message/notification/group/dismiss_group_notification_content.dart';
import 'message/notification/group/group_join_type_notification_content.dart';
import 'message/notification/group/group_member_allow_notification_content.dart';
import 'message/notification/group/group_member_mute_notification_content.dart';
import 'message/notification/group/group_mute_notification_content.dart';
import 'message/notification/group/group_private_chat_notification_content.dart';
import 'message/notification/group/group_set_manager_notification_content.dart';
import 'message/notification/group/kickoff_group_member_notification_content.dart';
import 'message/notification/group/modify_group_member_alias_notification_content.dart';
import 'message/notification/group/quit_group_notification_content.dart';
import 'message/notification/group/transfer_group_owner_notification_content.dart';
import 'message/notification/recall_notificiation_content.dart';
import 'message/notification/tip_notificiation_content.dart';
import 'message/pclogin_request_message_content.dart';
import 'message/ptext_message_content.dart';
import 'message/sound_message_content.dart';
import 'message/sticker_message_content.dart';
import 'message/streaming_text_generating_message_content.dart';
import 'message/streaming_text_generated_message_content.dart';
import 'message/text_message_content.dart';
import 'message/typing_message_content.dart';
import 'message/video_message_content.dart';
import 'model/channel_info.dart';
import 'model/chatroom_info.dart';
import 'model/chatroom_member_info.dart';
import 'model/conversation.dart';
import 'model/conversation_info.dart';
import 'model/conversation_search_info.dart';
import 'model/file_record.dart';
import 'model/friend_request.dart';
import 'model/group_info.dart';
import 'model/group_member.dart';
import 'model/group_search_info.dart';
import 'model/im_constant.dart';
import 'model/message_payload.dart';
import 'model/pc_online_info.dart';
import 'model/read_report.dart';
import 'model/unread_count.dart';
import 'model/user_info.dart';


typedef ConnectionStatusChangedCallback = void Function(int status);
typedef ReceiveMessageCallback = void Function(List<Message> messages, bool hasMore);

typedef SendMessageSuccessCallback = void Function(int messageUid, int timestamp);
typedef SendMediaMessageProgressCallback = void Function(int uploaded, int total);
typedef SendMediaMessageUploadedCallback = void Function(String remoteUrl);

typedef RecallMessageCallback = void Function(int messageUid);
typedef DeleteMessageCallback = void Function(int messageUid);

typedef MessageDeliveriedCallback = void Function(Map<String, int> deliveryMap);
typedef MessageReadedCallback = void Function(List<ReadReport> readReports);

typedef GroupInfoUpdatedCallback = void Function(List<GroupInfo> groupInfos);
typedef GroupMemberUpdatedCallback = void Function(
    String groupId, List<GroupMember> members);
typedef UserInfoUpdatedCallback = void Function(List<UserInfo> userInfos);

typedef FriendListUpdatedCallback = void Function(List<String> newFriends);
typedef FriendRequestListUpdatedCallback = void Function(List<String> newRequests);

typedef UserSettingsUpdatedCallback = void Function();

typedef ChannelInfoUpdatedCallback = void Function(List<ChannelInfo> channelInfos);

typedef OnlineEventCallback = void Function(List<UserOnlineState> onlineInfos);

typedef OperationFailureCallback = void Function(int errorCode);
typedef OperationSuccessVoidCallback = void Function();
typedef OperationSuccessIntCallback = void Function(int i);
typedef OperationSuccessIntPairCallback = void Function(int first, int second);
typedef OperationSuccessStringCallback = void Function(String strValue);
typedef OperationSuccessMessagesCallback = void Function(List<Message> messages);
typedef OperationSuccessMessageCallback = void Function(Message message);
typedef OperationSuccessUserInfosCallback = void Function(List<UserInfo>? userInfos);
typedef OperationSuccessUserInfoCallback = void Function(UserInfo userInfo);
typedef OperationSuccessGroupMembersCallback = void Function(List<GroupMember> members);
typedef OperationSuccessGroupInfoCallback = void Function(GroupInfo groupInfo);
typedef OperationSuccessChannelInfoCallback = void Function(ChannelInfo channelInfo);
typedef OperationSuccessChannelInfosCallback = void Function(
    List<ChannelInfo> channelInfos);
typedef OperationSuccessFilesCallback = void Function(List<FileRecord> files);
typedef OperationSuccessChatroomInfoCallback = void Function(ChatroomInfo chatroomInfo);
typedef OperationSuccessChatroomMemberInfoCallback = void Function(
    ChatroomMemberInfo memberInfo);
typedef OperationSuccessWatchUserOnlineCallback = void Function(List<UserOnlineState> members);
typedef OperationSuccessStringListCallback = void Function(List<String> strValues);

typedef GetUploadUrlSuccessCallback = void Function(String uploadUrl, String downloadUrl, String backupUploadUrl, int type);

enum FileRecordOrder {
TIME_DESC,
TIME_ASC,
SIZE_DESC,
SIZE_ASC,
}

/// 客户端和服务器之间的时间差值过大
/// 出现此错误时需要校准时间
const int kConnectionStatusTimeInconsistent = -9;

/// 没有授权或者授权过期，只有专业版IM服务才会出此状态
const int kConnectionStatusNotLicensed = -8;

/// 客户端被踢，可能是多端登录引起或者是被封禁或者是被API踢掉。
/// 出现此错误时需要退出到登录界面。
const int kConnectionStatusKickedOff = -7;

/// 密钥错误。一般是clientId不对，或者是连接的im跟请求token的im不是同一个环境，或者多端登录被踢出。
/// 出现此错误时需要退出到登录界面。
const int kConnectionStatusSecretKeyMismatch = -6;

/// token错误
/// 出现此错误时需要退出到登录界面。
const int kConnectionStatusTokenIncorrect = -5;

/// IM服务不可达
const int kConnectionStatusServerDown = -4;

/// 用户被封禁， 出现此错误时需要退出到登录界面。
const int kConnectionStatusRejected = -3;

/// 客户端退出登录
const int kConnectionStatusLogout = -2;

/// 未连接成功
const int kConnectionStatusUnconnected = -1;

/// 连接中
const int kConnectionStatusConnecting = 0;

/// 连接成功。连接成功是在同步成功之后。
const int kConnectionStatusConnected = 1;

/// 同步中。同步成功后会转入到连接成功状态。
const int kConnectionStatusReceiving = 2;

class ConnectionStatusChangedEvent {
  int connectionStatus;

  ConnectionStatusChangedEvent(this.connectionStatus);
}

class UserSettingUpdatedEvent {}

class ReceiveMessagesEvent {
  List<Message> messages;
  bool hasMore;

  ReceiveMessagesEvent(this.messages, this.hasMore);
}

class RecallMessageEvent {
  int messageUid;

  RecallMessageEvent(this.messageUid);
}

class DeleteMessageEvent {
  int? messageUid;
  int? messageId;

  DeleteMessageEvent({this.messageId, this.messageUid});
}

class MessageDeliveriedEvent {
  Map<String, int> deliveryMap;

  MessageDeliveriedEvent(this.deliveryMap);
}

class MessageReadedEvent {
  List<ReadReport> readedReports;

  MessageReadedEvent(this.readedReports);
}

class MessageUpdatedEvent {
  int messageId;

  MessageUpdatedEvent(this.messageId);
}

class GroupInfoUpdatedEvent {
  List<GroupInfo> groupInfos;

  GroupInfoUpdatedEvent(this.groupInfos);
}

class GroupMembersUpdatedEvent {
  String groupId;
  List<GroupMember> members;

  GroupMembersUpdatedEvent(this.groupId, this.members);
}

class UserInfoUpdatedEvent {
  List<UserInfo> userInfos;

  UserInfoUpdatedEvent(this.userInfos);
}

class FriendUpdateEvent {
  List<String> newUsers;

  FriendUpdateEvent(this.newUsers);
}

class FriendRequestUpdateEvent {
  List<String> newUserRequests;

  FriendRequestUpdateEvent(this.newUserRequests);
}

class ChannelInfoUpdateEvent {
  List<ChannelInfo> channelInfos;

  ChannelInfoUpdateEvent(this.channelInfos);
}

class UserOnlineStateUpdatedEvent {
  List<UserOnlineState> onlineInfos;

  UserOnlineStateUpdatedEvent(this.onlineInfos);
}

class ClearMessagesEvent {
  Conversation conversation;

  ClearMessagesEvent(this.conversation);
}

class ClearConversationUnreadEvent {
  Conversation conversation;

  ClearConversationUnreadEvent(this.conversation);
}

class ClearConversationsUnreadEvent {
  List<ConversationType> types;
  List<int> lines;

  ClearConversationsUnreadEvent(this.types, this.lines);
}

class ClearFriendRequestUnreadEvent {}

class SendMessageStartEvent {
  Message message;

  SendMessageStartEvent(this.message);
}

class SendMessageSuccessEvent {
  Message message;
  int messageId;
  int messageUid;
  int timestamp;

  SendMessageSuccessEvent(this.message, this.messageId, this.messageUid, this.timestamp);
}

class SendMessageProgressEvent {
  Message message;
  int messageId;
  int total;
  int uploaded;

  SendMessageProgressEvent(this.message, this.messageId, this.total, this.uploaded);
}

class SendMessageMediaUploadedEvent {
  Message message;
  int messageId;
  String mediaUrl;

  SendMessageMediaUploadedEvent(this.message, this.messageId, this.mediaUrl);
}

class SendMessageFailureEvent {
  Message message;
  int messageId;
  int errorCode;

  SendMessageFailureEvent(this.message, this.messageId, this.errorCode);
}

class ConversationDraftUpdatedEvent {
  Conversation conversation;
  String draft;

  ConversationDraftUpdatedEvent(this.conversation, this.draft);
}

class ConversationTopUpdatedEvent {
  Conversation conversation;
  int top;

  ConversationTopUpdatedEvent(this.conversation, this.top);
}

class ConversationSilentUpdatedEvent {
  Conversation conversation;
  bool silent;

  ConversationSilentUpdatedEvent(this.conversation, this.silent);
}

abstract class DefaultPortraitProvider {
  String userDefaultPortrait(UserInfo userInfo);
  String? groupDefaultPortrait(GroupInfo groupInfo, List<UserInfo> userInfos);
}

class Imclient {
  static EventBus get IMEventBus {
    return ImclientPlatform.instance.IMEventBus;
  }

  ///客户端ID，客户端的唯一标示。获取IM Token时必须带上正确的客户端ID，否则会无法连接成功。
  static Future<String> get clientId async {
    return ImclientPlatform.instance.clientId;
  }

  ///客户端是否调用过connect
  static Future<bool> get isLogined async {
    return ImclientPlatform.instance.isLogined;
  }

  ///连接状态
  static Future<int> get connectionStatus async {
    return ImclientPlatform.instance.connectionStatus;
  }

  ///当前用户ID
  static String get currentUserId {
    return ImclientPlatform.instance.currentUserId;
  }

  ///当前服务器与客户端时间的差值，单位是毫秒，只能是初略估计，不精确。
  static Future<int> get serverDeltaTime async {
    return ImclientPlatform.instance.serverDeltaTime;
  }

  ///开启协议栈日志
  static Future<void> startLog() async {
    return ImclientPlatform.instance.startLog();
  }

  ///结束协议栈日志
  static Future<void> stopLog() async {
    return ImclientPlatform.instance.stopLog();
  }

  ///设置发送日志的命令，当发送此命令的文本消息时，会上传日志文件在当前会话中
  static Future<void> setSendLogCommand(String sendLogCmd) async {
    return ImclientPlatform.instance.setSendLogCommand(sendLogCmd);
  }

  ///使用国密。国密需要和专业版IM服务同时开启，并且不支持切换。
  static Future<void> useSM4() async {
    return ImclientPlatform.instance.useSM4();
  }

  ///设置lite模式，lite模式下，协议栈不存储任何信息，也不拉取历史消息
  static Future<void> setLiteMode(bool liteMode) async {
    return ImclientPlatform.instance.setLiteMode(liteMode);
  }

  ///设置推送token和类型。iOS平台类型为0，android平台请参考推送服务
  static Future<void> setDeviceToken(int pushType, String deviceToken) async {
    return ImclientPlatform.instance.setDeviceToken(pushType, deviceToken);
  }

  ///设置voip推送token，只支持iOS平台
  static Future<void> setVoipDeviceToken(String voipToken) async {
    return ImclientPlatform.instance.setVoipDeviceToken(voipToken);
  }

  ///设置备选网络策略，双网相关知识请参考：https://docs.wildfirechat.cn/blogs/政企内外双网解决方案.html
  static Future<void> setBackupAddressStrategy(int strategy) async {
    return ImclientPlatform.instance.setBackupAddressStrategy(strategy);
  }

  ///设置备选地址和端口，只能设置一个。
  static Future<void> setBackupAddress(String host, int port) async {
    return ImclientPlatform.instance.setBackupAddress(host, port);
  }

  ///设置HTTP User Agent
  static Future<void> setProtoUserAgent(String agent) async {
    return ImclientPlatform.instance.setProtoUserAgent(agent);
  }

  ///Http 添加header，可以添加多个
  static Future<void> addHttpHeader(String header, String value) async {
    return ImclientPlatform.instance.addHttpHeader(header, value);
  }

  static void setDefaultPortraitProvider(DefaultPortraitProvider provider) {
    ImclientPlatform.setDefaultPortraitProvider(provider);
  }

  ///设置代理
  static Future<void> setProxyInfo(String host, String ip, int port, {String? userName, String? password}) async {
    return ImclientPlatform.instance.setProxyInfo(host, ip, port, userName:userName, password:password);
  }

  ///协议栈版本
  static Future<String> get protoRevision async {
    return ImclientPlatform.instance.protoRevision;
  }


  ///获取协议栈日志文件路径
  static Future<List<String>> get logFilesPath async {
    return ImclientPlatform.instance.logFilesPath;
  }

  ///初始化SDK。必须在程序启动之后在所有操作之前初始化，之后才可以做其它操作。
  static void init(
      ConnectionStatusChangedCallback connectionStatusChangedCallback,
      ReceiveMessageCallback receiveMessageCallback,
      RecallMessageCallback recallMessageCallback,
      DeleteMessageCallback deleteMessageCallback,
      {MessageDeliveriedCallback? messageDeliveriedCallback,
        MessageReadedCallback? messageReadedCallback,
        GroupInfoUpdatedCallback? groupInfoUpdatedCallback,
        GroupMemberUpdatedCallback? groupMemberUpdatedCallback,
        UserInfoUpdatedCallback? userInfoUpdatedCallback,
        FriendListUpdatedCallback? friendListUpdatedCallback,
        FriendRequestListUpdatedCallback? friendRequestListUpdatedCallback,
        UserSettingsUpdatedCallback? userSettingsUpdatedCallback,
        ChannelInfoUpdatedCallback? channelInfoUpdatedCallback,
        OnlineEventCallback? onlineEventCallback}) async {

    registerMessageContent(addGroupMemberNotificationContentMeta);
    registerMessageContent(changeGroupNameNotificationContentMeta);
    registerMessageContent(changeGroupPortraitNotificationContentMeta);
    registerMessageContent(createGroupNotificationContentMeta);
    registerMessageContent(dismissGroupNotificationContentMeta);
    registerMessageContent(groupJoinTypeNotificationContentMeta);
    registerMessageContent(groupMemberAllowNotificationContentMeta);
    registerMessageContent(groupMemberMuteNotificationContentMeta);
    registerMessageContent(groupMuteNotificationContentMeta);
    registerMessageContent(groupPrivateChatNotificationContentMeta);
    registerMessageContent(groupSetManagerNotificationContentMeta);
    registerMessageContent(kickoffGroupMemberNotificationContentMeta);
    registerMessageContent(modifyGroupMemberAliasNotificationContentMeta);
    registerMessageContent(quitGroupNotificationContentMeta);
    registerMessageContent(transferGroupOwnerNotificationContentMeta);

    registerMessageContent(recallNotificationContentMeta);
    registerMessageContent(tipNotificationContentMeta);

    registerMessageContent(callStartContentMeta);
    registerMessageContent(callAddParticipantsNotificationContentMeta);

    registerMessageContent(cardContentMeta);
    registerMessageContent(compositeContentMeta);
    registerMessageContent(deleteMessageContentMeta);
    registerMessageContent(fileContentMeta);
    registerMessageContent(friendAddedContentMeta);
    registerMessageContent(friendGreetingContentMeta);
    registerMessageContent(imageContentMeta);
    registerMessageContent(linkContentMeta);
    registerMessageContent(locationMessageContentMeta);
    registerMessageContent(pcLoginContentMeta);
    registerMessageContent(ptextContentMeta);
    registerMessageContent(soundContentMeta);
    registerMessageContent(stickerContentMeta);
    registerMessageContent(streamingTextGeneratingContentMeta);
    registerMessageContent(streamingTextGeneratedContentMeta);
    registerMessageContent(textContentMeta);
    registerMessageContent(typingContentMeta);
    registerMessageContent(videoContentMeta);

    ImclientPlatform.instance.init(connectionStatusChangedCallback,
        receiveMessageCallback,
        recallMessageCallback,
        deleteMessageCallback,
        messageDeliveriedCallback: messageDeliveriedCallback,
        messageReadedCallback: messageReadedCallback,
        groupInfoUpdatedCallback: groupInfoUpdatedCallback,
        groupMemberUpdatedCallback: groupMemberUpdatedCallback,
        userInfoUpdatedCallback: userInfoUpdatedCallback,
        friendListUpdatedCallback: friendListUpdatedCallback,
        friendRequestListUpdatedCallback: friendRequestListUpdatedCallback,
        userSettingsUpdatedCallback: userSettingsUpdatedCallback,
        channelInfoUpdatedCallback: channelInfoUpdatedCallback,
        onlineEventCallback: onlineEventCallback);
  }

  ///注册消息，所有的预制消息和自定义消息都必须先注册才可以使用。
  static void registerMessageContent(MessageContentMeta contentMeta) {
    ImclientPlatform.instance.registerMessage(contentMeta);
  }

  /// 连接IM服务。调用连接之后才可以调用获取数据接口。连接状态会通过连接状态回调返回。
  /// [host]为IM服务域名或IP，必须im.example.com或114.144.114.144，不带http头和端口。
  /// 返回数据为上一次连接的时间，如果首次连接返回0。UI层可以根据间隔判断是否添加等待同步画面
  static Future<int> connect(String host, String userId, String token) async {
    return ImclientPlatform.instance.connect(host, userId, token);
  }

  ///断开IM服务连接。
  /// * disablePush 是否继续接受推送。
  /// * clearSession 是否清除session
  static Future<void> disconnect(
      {bool disablePush = false, bool clearSession = false}) async {
    return ImclientPlatform.instance.disconnect(disablePush: disablePush, clearSession: clearSession);
  }

  ///获取会话列表
  static Future<List<ConversationInfo>> getConversationInfos(
      List<ConversationType> types, List<int> lines) async {
    return ImclientPlatform.instance.getConversationInfos(types, lines);
  }

  ///获取会话信息
  static Future<ConversationInfo> getConversationInfo(
      Conversation conversation) async {
    return ImclientPlatform.instance.getConversationInfo(conversation);
  }

  ///搜索会话信息
  static Future<List<ConversationSearchInfo>> searchConversation(
      String keyword, List<ConversationType> types, List<int> lines) async {
    return ImclientPlatform.instance.searchConversation(keyword, types, lines);
  }

  ///移除会话
  static Future<void> removeConversation(
      Conversation conversation, bool clearMessage) async {
    return ImclientPlatform.instance.removeConversation(conversation, clearMessage);
  }

  ///设置/取消会话置顶
  static void setConversationTop(
      Conversation conversation,
      int isTop,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setConversationTop(conversation, isTop, successCallback, errorCallback);
  }

  ///设置/取消会话免到扰
  static void setConversationSilent(
      Conversation conversation,
      bool isSilent,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setConversationSilent(conversation, isSilent, successCallback, errorCallback);
  }

  ///保存草稿
  static Future<void> setConversationDraft(
      Conversation conversation, String draft) async {
    return ImclientPlatform.instance.setConversationDraft(conversation, draft);
  }

  ///设置会话时间戳
  static Future<void> setConversationTimestamp(
      Conversation conversation, int timestamp) async {
    return ImclientPlatform.instance.setConversationTimestamp(conversation, timestamp);
  }

  ///设置会话中第一个未读消息ID
  static Future<int> getFirstUnreadMessageId(Conversation conversation) async {
    return ImclientPlatform.instance.getFirstUnreadMessageId(conversation);
  }

  ///设置会话未读状态
  static Future<UnreadCount> getConversationUnreadCount(
      Conversation conversation) async {
    return ImclientPlatform.instance.getConversationUnreadCount(conversation);
  }

  ///设置某些类型会话未读状态
  static Future<UnreadCount> getConversationsUnreadCount(
      List<ConversationType> types, List<int> lines) async {
    return ImclientPlatform.instance.getConversationsUnreadCount(types, lines);
  }

  ///清除一个会话的未读状态
  static Future<bool> clearConversationUnreadStatus(
      Conversation conversation) async {
    return ImclientPlatform.instance.clearConversationUnreadStatus(conversation);
  }

  ///清除某些类型会话的未读状态
  static Future<bool> clearConversationsUnreadStatus(
      List<ConversationType> types, List<int> lines) async {
    return ImclientPlatform.instance.clearConversationsUnreadStatus(types, lines);
  }

  ///清除一个会话的未读状态
  static Future<bool> clearConversationUnreadStatusBeforeMessage(
      Conversation conversation, int messageId) async {
    return ImclientPlatform.instance.clearConversationUnreadStatusBeforeMessage(conversation, messageId);
  }

  ///请求某条消息的未读状态
  static Future<bool> clearMessageUnreadStatus(int messageId) async {
    return ImclientPlatform.instance.clearMessageUnreadStatus(messageId);
  }

  ///设置会话为未读
  static Future<bool> markAsUnRead(Conversation conversation, bool syncToOtherClient) async {
    return ImclientPlatform.instance.markAsUnRead(conversation, syncToOtherClient);
  }

  ///获取会话的已读状态
  static Future<Map<String, int>> getConversationRead(
      Conversation conversation) async {
    return ImclientPlatform.instance.getConversationRead(conversation);
  }

  ///获取会话的消息送达状态
  static Future<Map<String, int>> getMessageDelivery(
      Conversation conversation) async {
    return ImclientPlatform.instance.getMessageDelivery(conversation);
  }

  ///消息负载解码为消息内容
  static MessageContent decodeMessageContent(MessagePayload payload) {
    return ImclientPlatform.instance.decodeMessageContent(payload);
  }

  ///获取会话的消息列表
  /// count 可以控制方向，>0 表示获取之前更旧的; <0 更新的
  /// >0 返回值是 [older...newer]
  /// <0 返回值是 [newer...older]
  static Future<List<Message>> getMessages(
      Conversation conversation, int fromIndex, int count,
      {List<int>? contentTypes, String? withUser}) async {
    return ImclientPlatform.instance.getMessages(conversation, fromIndex, count, contentTypes: contentTypes, withUser: withUser);
  }

  ///根据消息状态获取会话的消息列表
  static Future<List<Message>> getMessagesByStatus(Conversation conversation,
      int fromIndex, int count, List<MessageStatus> messageStatus,
      {String? withUser}) async {
    return ImclientPlatform.instance.getMessagesByStatus(conversation, fromIndex, count, messageStatus);
  }

  ///获取某些类型会话的消息列表
  static Future<List<Message>> getConversationsMessages(
      List<ConversationType> types, List<int> lines, int fromIndex, int count,
      {List<int>? contentTypes, String? withUser}) async {
    return ImclientPlatform.instance.getConversationsMessages(types, lines, fromIndex, count, contentTypes: contentTypes, withUser: withUser);
  }

  ///根据消息状态获取某些类型会话的消息列表
  static Future<List<Message>> getConversationsMessageByStatus(
      List<ConversationType> types,
      List<int> lines,
      int fromIndex,
      int count,
      List<MessageStatus> messageStatus,
      {String? withUser}) async {
    return ImclientPlatform.instance.getConversationsMessageByStatus(types, lines, fromIndex, count, messageStatus, withUser: withUser);
  }

  ///获取远端历史消息
  static void getRemoteMessages(
      Conversation conversation,
      int beforeMessageUid,
      int count,
      OperationSuccessMessagesCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? contentTypes}) {
    ImclientPlatform.instance.getRemoteMessages(conversation, beforeMessageUid, count, successCallback, errorCallback, contentTypes: contentTypes);
  }

  ///获取服务器端的某条消息
  static void getRemoteMessage(
      int messageUid,
      OperationSuccessMessageCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.getRemoteMessage(messageUid, successCallback, errorCallback);
  }

  ///根据消息Id获取消息
  static Future<Message?> getMessage(int messageId) async {
    return ImclientPlatform.instance.getMessage(messageId);
  }

  ///根据消息Uid获取消息
  static Future<Message?> getMessageByUid(int messageUid) async {
    return ImclientPlatform.instance.getMessageByUid(messageUid);
  }

  ///搜索某个会话内消息
  static Future<List<Message>> searchMessages(Conversation conversation,
      String keyword, bool order, int limit, int offset) async {
    return ImclientPlatform.instance.searchMessages(conversation, keyword, order, limit, offset);
  }

  ///搜索某些类会话内消息
  static Future<List<Message>> searchConversationsMessages(
      List<ConversationType> types,
      List<int> lines,
      String keyword,
      int fromIndex,
      int count, {
        List<int>? contentTypes,
      }) async {
    return ImclientPlatform.instance.searchConversationsMessages(types, lines, keyword, fromIndex, count, contentTypes: contentTypes);
  }

  ///发送消息
  static Future<Message> sendMessage(
      Conversation conversation, MessageContent content,
      {List<String>? toUsers,
        int expireDuration = 0,
        required SendMessageSuccessCallback successCallback,
        required OperationFailureCallback errorCallback}) async {
    return sendMediaMessage(conversation, content,
        toUsers: toUsers,
        expireDuration: expireDuration,
        successCallback: successCallback,
        errorCallback: errorCallback);
  }

  ///发送媒体类型消息
  static Future<Message> sendMediaMessage(
      Conversation conversation, MessageContent content,
      {List<String>? toUsers,
        int expireDuration = 0,
        required SendMessageSuccessCallback successCallback,
        required OperationFailureCallback errorCallback,
        SendMediaMessageProgressCallback? progressCallback,
        SendMediaMessageUploadedCallback? uploadedCallback}) async {
    return ImclientPlatform.instance.sendMediaMessage(conversation, content, toUsers: toUsers, expireDuration: expireDuration, successCallback: successCallback, errorCallback: errorCallback, progressCallback: progressCallback, uploadedCallback: uploadedCallback);
  }

  ///发送已保存消息
  @Deprecated('Use another one.')
  static Future<bool> sendSavedMessage(int messageId,
      {int expireDuration = 0,
        required SendMessageSuccessCallback successCallback,
        required OperationFailureCallback errorCallback}) async {
    return ImclientPlatform.instance.sendSavedMessage(messageId, expireDuration: expireDuration, successCallback: successCallback, errorCallback: errorCallback);
  }

  ///发送已保存消息
  static Future<bool> sendSavedMessage2(Message message,
      {int expireDuration = 0,
        required SendMessageSuccessCallback successCallback,
        required OperationFailureCallback errorCallback}) async {
    return ImclientPlatform.instance.sendSavedMessage2(message, expireDuration: expireDuration, successCallback: successCallback, errorCallback: errorCallback);
  }

  static Future<bool> cancelSendingMessage(int messageId) async {
    return ImclientPlatform.instance.cancelSendingMessage(messageId);
  }

  ///撤回消息
  static void recallMessage(
      int messageUid,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    ImclientPlatform.instance.recallMessage(messageUid, successCallback, errorCallback);
  }

  ///map转换为消息内容
  static MessageContent contentFromMap(Map<dynamic, dynamic> map) {
    return ImclientPlatform.instance.contentFromMap(map);
  }

  ///map转换为消息
  static Message messageFromMap(Map<dynamic, dynamic> map) {
    return ImclientPlatform.instance.messageFromMap(map);
  }

  ///上传媒体数据
  static void uploadMedia(
      String fileName,
      Uint8List mediaData,
      MediaType mediaType,
      OperationSuccessStringCallback successCallback,
      SendMediaMessageProgressCallback progressCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.uploadMedia(fileName, mediaData, mediaType.index, successCallback, progressCallback, errorCallback);
  }

  ///上传媒体文件
  static void uploadMediaFile(
      String filePath,
      MediaType mediaType,
      OperationSuccessStringCallback successCallback,
      SendMediaMessageProgressCallback progressCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.uploadMediaFile(filePath, mediaType.index, successCallback, progressCallback, errorCallback);
  }

  ///获取上传地址，仅支持大文件上传功能时可用
  static void getMediaUploadUrl(
      String fileName,
      int mediaType,
      String contentType,
      GetUploadUrlSuccessCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.getMediaUploadUrl(fileName, mediaType, contentType, successCallback, errorCallback);
  }

  ///是否支持大文件上传功能
  static Future<bool> isSupportBigFilesUpload() async {
    return ImclientPlatform.instance.isSupportBigFilesUpload();
  }

  ///删除消息
  static Future<bool> deleteMessage(int messageId) async {
    return ImclientPlatform.instance.deleteMessage(messageId);
  }

  ///批量删除消息
  static Future<bool> batchDeleteMessages(List<int> messageUids) async {
    return ImclientPlatform.instance.batchDeleteMessages(messageUids);
  }

  ///删除本地和远端消息，仅当专业版IM支持，专业版IM服务中超级群组不支持服务器端删除.
  static void deleteRemoteMessage(int messageUid,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.deleteRemoteMessage(messageUid, successCallback, errorCallback);
  }

  ///清空会话内消息
  static Future<bool> clearMessages(Conversation conversation,
      {int before = 0}) async {
    return ImclientPlatform.instance.clearMessages(conversation, before: before);
  }

  ///清空会话内消息保留最近指定条数的消息
  static Future<bool> clearMessagesKeepLatest(Conversation conversation, int keepCount) async {
    return ImclientPlatform.instance.clearMessagesKeepLatest(conversation, keepCount);
  }

  ///清除服务器端会话消息
  static void clearRemoteConversationMessage(Conversation conversation,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.clearRemoteConversationMessage(conversation, successCallback, errorCallback);
  }

  ///设置消息已经播放
  static Future<void> setMediaMessagePlayed(int messageId) async {
    return ImclientPlatform.instance.setMediaMessagePlayed(messageId);
  }

  static Future<bool> setMessageLocalExtra(int messageId, String localExtra) async {
    return ImclientPlatform.instance.setMessageLocalExtra(messageId, localExtra);
  }

  ///插入消息
  static Future<Message> insertMessage(Conversation conversation, String sender,
      MessageContent content, int status, int serverTime, {List<String>? toUsers}) async {
    return ImclientPlatform.instance.insertMessage(conversation, sender, content, status, serverTime, toUsers: toUsers);
  }

  ///更新消息内容
  static Future<void> updateMessage(
      int messageId, MessageContent content) async {
    return ImclientPlatform.instance.updateMessage(messageId, content);
  }

  ///更新消息内容
  static void updateRemoteMessageContent(
      int messageUid, MessageContent content, bool distribute, bool updateLocal,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.updateRemoteMessageContent(messageUid, content, distribute, updateLocal, successCallback, errorCallback);
  }

  ///更新消息状态
  static Future<void> updateMessageStatus(
      int messageId, MessageStatus status) async {
    return ImclientPlatform.instance.updateMessageStatus(messageId, status);
  }

  ///获取会话内消息数量
  static Future<int> getMessageCount(Conversation conversation) async {
    return ImclientPlatform.instance.getMessageCount(conversation);
  }

  ///获取用户信息
  static Future<UserInfo?> getUserInfo(String userId,
      {String? groupId, bool refresh = false}) async {
    return ImclientPlatform.instance.getUserInfo(userId, groupId: groupId, refresh: refresh);
  }

  ///批量获取用户信息
  static Future<List<UserInfo>> getUserInfos(List<String> userIds,
      {String? groupId}) async {
    return ImclientPlatform.instance.getUserInfos(userIds, groupId: groupId);
  }

  ///搜索用户
  static void searchUser(
      String keyword,
      int searchType,
      int page,
      OperationSuccessUserInfosCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.searchUser(keyword, searchType, page, successCallback, errorCallback);
  }

  ///异步获取用户信息
  static void getUserInfoAsync(
      String userId,
      OperationSuccessUserInfoCallback successCallback,
      OperationFailureCallback errorCallback,
      {String? groupId, bool refresh = false}) {
    ImclientPlatform.instance.getUserInfoAsync(userId, successCallback, errorCallback, refresh: refresh, groupId: groupId);
  }

  ///是否是好友
  static Future<bool> isMyFriend(String userId) async {
    return ImclientPlatform.instance.isMyFriend(userId);
  }

  ///获取好友用户ID列表
  static Future<List<String>> getMyFriendList({bool refresh = false}) async {
    return ImclientPlatform.instance.getMyFriendList(refresh: refresh);
  }

  ///搜索好友
  static Future<List<UserInfo>> searchFriends(String keyword) async {
    return ImclientPlatform.instance.searchFriends(keyword);
  }

  ///获取好友列表
  static Future<List<Friend>> getFriends({bool refresh = false}) async {
    return ImclientPlatform.instance.getFriends(refresh);
  }

  ///设置用户好友请求是否需要验证
  static void setAddFriendNeedVerify(
      bool enable,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    setUserSetting(28, "", enable?"0":"1", successCallback, errorCallback);
  }

  ///获取用户好友请求是否需要验证
  static Future<bool> isAddFriendNeedVerify() async {
    String value = await getUserSetting(28, "");
    if("1" == value) {
      return false;
    }
    return true;
  }

  ///搜索群组
  static Future<List<GroupSearchInfo>> searchGroups(String keyword) async {
    return ImclientPlatform.instance.searchGroups(keyword);
  }

  ///获取收到的好友请求列表
  static Future<List<FriendRequest>> getIncommingFriendRequest() async {
    return ImclientPlatform.instance.getIncommingFriendRequest();
  }

  ///获取发出去的好友请求列表
  static Future<List<FriendRequest>> getOutgoingFriendRequest() async {
    return ImclientPlatform.instance.getOutgoingFriendRequest();
  }

  ///获取某个用户相关的好友请求
  static Future<FriendRequest?> getFriendRequest(
      String userId, FriendRequestDirection direction) async {
    return ImclientPlatform.instance.getFriendRequest(userId, direction);
  }

  ///同步远程好友请求信息
  static Future<void> loadFriendRequestFromRemote() async {
    return ImclientPlatform.instance.loadFriendRequestFromRemote();
  }

  ///获取未读好友请求数
  static Future<int> getUnreadFriendRequestStatus() async {
    return ImclientPlatform.instance.getUnreadFriendRequestStatus();
  }

  ///清除未读好友请求计数
  static Future<bool> clearUnreadFriendRequestStatus() async {
    return ImclientPlatform.instance.clearUnreadFriendRequestStatus();
  }

  ///清空好友请求
  ///direction 0是收，1是发。
  static Future<bool> clearFriendRequest(int direction, {int beforeTime = 0}) async {
    return ImclientPlatform.instance.clearFriendRequest(direction, beforeTime);
  }

  ///删除好友请求
  ///direction 0是收，1是发。
  static Future<bool> deleteFriendRequest(String userId, int direction) async {
    return ImclientPlatform.instance.deleteFriendRequest(userId, direction);
  }

  ///删除好友
  static void deleteFriend(
      String userId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.deleteFriend(userId, successCallback, errorCallback);
  }

  ///发送好友请求
  static void sendFriendRequest(
      String userId,
      String reason,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.sendFriendRequest(userId, reason, successCallback, errorCallback);
  }

  ///处理好友请求
  static void handleFriendRequest(
      String userId,
      bool accept,
      String extra,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.handleFriendRequest(userId, accept, extra, successCallback, errorCallback);
  }

  ///获取好友备注名
  static Future<String?> getFriendAlias(String userId) async {
    return ImclientPlatform.instance.getFriendAlias(userId);
  }

  ///设置好友备注名
  static void setFriendAlias(
      String friendId,
      String? alias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setFriendAlias(friendId, alias, successCallback, errorCallback);
  }

  ///获取好友extra信息
  static Future<String> getFriendExtra(String userId) async {
    return ImclientPlatform.instance.getFriendExtra(userId);
  }

  ///是否是黑名单用户
  static Future<bool> isBlackListed(String userId) async {
    return ImclientPlatform.instance.isBlackListed(userId);
  }

  ///获取黑名单列表
  static Future<List<String>> getBlackList({bool refresh = false}) async {
    return ImclientPlatform.instance.getBlackList(refresh: refresh);
  }

  ///设置/取消用户黑名单
  static void setBlackList(
      String userId,
      bool isBlackListed,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setBlackList(userId, isBlackListed, successCallback, errorCallback);
  }

  ///获取群成员列表
  static Future<List<GroupMember>> getGroupMembers(String groupId,
      {bool refresh = false}) async {
    return ImclientPlatform.instance.getGroupMembers(groupId, refresh: refresh);
  }

  ///获取指定数目的群成员列表
  static Future<List<GroupMember>> getGroupMembersByCount(String groupId, int count) async {
    return ImclientPlatform.instance.getGroupMembersByCount(groupId, count);
  }

  ///根据群成员类型获取群成员列表
  static Future<List<GroupMember>> getGroupMembersByTypes(
      String groupId, GroupMemberType memberType) async {
    return ImclientPlatform.instance.getGroupMembersByTypes(groupId, memberType);
  }

  ///异步获取群成员列表
  static void getGroupMembersAsync(String groupId,
      {bool refresh = false,
        required OperationSuccessGroupMembersCallback successCallback,
        required OperationFailureCallback errorCallback}) {
    ImclientPlatform.instance.getGroupMembersAsync(groupId, refresh: refresh, successCallback: successCallback, errorCallback: errorCallback);
  }

  ///获取群信息
  static Future<GroupInfo?> getGroupInfo(String groupId,
      {bool refresh = false}) async {
    return ImclientPlatform.instance.getGroupInfo(groupId, refresh: refresh);
  }

  ///批量获取群信息
  static Future<List<GroupInfo>> getGroupInfos(List<String> groupIds,
      {bool refresh = false}) async {
    return ImclientPlatform.instance.getGroupInfos(groupIds, refresh: refresh);
  }

  ///异步获取群信息
  static void getGroupInfoAsync(String groupId,
      {bool refresh = false,
        required OperationSuccessGroupInfoCallback successCallback,
        required OperationFailureCallback errorCallback}) {
    ImclientPlatform.instance.getGroupInfoAsync(groupId, refresh: refresh, successCallback: successCallback, errorCallback: errorCallback);
  }

  ///获取单个群成员信息
  static Future<GroupMember?> getGroupMember(
      String groupId, String memberId) async {
    return ImclientPlatform.instance.getGroupMember(groupId, memberId);
  }

  ///创建群组，groupId可以为空。
  static void createGroup(
      String? groupId,
      String? groupName,
      String? groupPortrait,
      int type,
      List<String> members,
      OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    ImclientPlatform.instance.createGroup(groupId, groupName, groupPortrait, type, members, successCallback, errorCallback, notifyLines: notifyLines, notifyContent: notifyContent);
  }

  ///添加群成员
  static void addGroupMembers(
      String groupId,
      List<String> members,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    ImclientPlatform.instance.addGroupMembers(groupId, members, successCallback, errorCallback, notifyLines: notifyLines, notifyContent: notifyContent);
  }

  ///移除群成员
  static void kickoffGroupMembers(
      String groupId,
      List<String> members,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    ImclientPlatform.instance.kickoffGroupMembers(groupId, members, successCallback, errorCallback, notifyLines: notifyLines, notifyContent: notifyContent);
  }

  ///退出群组
  static void quitGroup(
      String groupId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    ImclientPlatform.instance.quitGroup(groupId, successCallback, errorCallback, notifyLines: notifyLines, notifyContent: notifyContent);
  }

  ///退出群组
  static void quitGroupEx(
      String groupId,
      bool keepMessage,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    ImclientPlatform.instance.quitGroupEx(groupId, keepMessage, successCallback, errorCallback, notifyLines: notifyLines, notifyContent: notifyContent);
  }

  ///解散群组
  static void dismissGroup(
      String groupId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    ImclientPlatform.instance.dismissGroup(groupId, successCallback, errorCallback, notifyLines: notifyLines, notifyContent: notifyContent);
  }

  ///修改群组信息
  static void modifyGroupInfo(
      String groupId,
      ModifyGroupInfoType modifyType,
      String newValue,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    ImclientPlatform.instance.modifyGroupInfo(groupId, modifyType, newValue, successCallback, errorCallback, notifyLines: notifyLines, notifyContent: notifyContent);
  }

  ///修改自己的群名片
  static void modifyGroupAlias(
      String groupId,
      String newAlias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    ImclientPlatform.instance.modifyGroupAlias(groupId, newAlias, successCallback, errorCallback, notifyLines: notifyLines, notifyContent: notifyContent);
  }

  ///修改群成员的群名片
  static void modifyGroupMemberAlias(
      String groupId,
      String memberId,
      String newAlias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    ImclientPlatform.instance.modifyGroupMemberAlias(groupId, memberId, newAlias, successCallback, errorCallback, notifyLines: notifyLines, notifyContent: notifyContent);
  }

  ///转移群组
  static void transferGroup(
      String groupId,
      String newOwner,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    ImclientPlatform.instance.transferGroup(groupId, newOwner, successCallback, errorCallback, notifyLines: notifyLines, notifyContent: notifyContent);
  }

  ///设置/取消群管理员
  static void setGroupManager(
      String groupId,
      bool isSet,
      List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    ImclientPlatform.instance.setGroupManager(groupId, isSet, memberIds, successCallback, errorCallback, notifyLines: notifyLines, notifyContent: notifyContent);
  }

  ///禁言/取消禁言群成员
  static void muteGroupMember(
      String groupId,
      bool isSet,
      List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    ImclientPlatform.instance.muteGroupMember(groupId, isSet, memberIds, successCallback, errorCallback, notifyLines: notifyLines, notifyContent: notifyContent);
  }

  ///设置/取消群白名单
  static void allowGroupMember(
      String groupId,
      bool isSet,
      List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    ImclientPlatform.instance.allowGroupMember(groupId, isSet, memberIds,
        successCallback, errorCallback, notifyLines: notifyLines, notifyContent: notifyContent);
  }

  static Future<String> getGroupRemark(String groupId) async {
    return ImclientPlatform.instance.getGroupRemark(groupId);
  }

  static void setGroupRemark(String groupId, String remark,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setGroupRemark(groupId, remark,
        successCallback, errorCallback);
  }

  ///获取收藏群组列表
  static Future<List<String>?> getFavGroups() async {
    return ImclientPlatform.instance.getFavGroups();
  }

  ///是否收藏群组
  static Future<bool> isFavGroup(String groupId) async {
    return ImclientPlatform.instance.isFavGroup(groupId);
  }

  ///设置/取消收藏群组
  static void setFavGroup(
      String groupId,
      bool isFav,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setFavGroup(groupId, isFav, successCallback, errorCallback);
  }

  ///获取用户设置
  static Future<String> getUserSetting(int scope, String key) async {
    return ImclientPlatform.instance.getUserSetting(scope, key);
  }

  ///获取某类用户设置
  static Future<Map<String, String>> getUserSettings(int scope) async {
    return ImclientPlatform.instance.getUserSettings(scope);
  }

  ///设置用户设置
  static void setUserSetting(
      int scope,
      String key,
      String value,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setUserSetting(scope, key, value, successCallback, errorCallback);
  }

  ///修改当前用户信息
  static void modifyMyInfo(
      Map<ModifyMyInfoType, String> values,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.modifyMyInfo(values, successCallback, errorCallback);
  }

  ///是否全局静音
  static Future<bool> isGlobalSilent() async {
    return ImclientPlatform.instance.isGlobalSilent();
  }

  ///设置/取消全局静音
  static void setGlobalSilent(
      bool isSilent,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setGlobalSilent(isSilent, successCallback, errorCallback);
  }

  static Future<bool> isVoipNotificationSilent() async {
    return ImclientPlatform.instance.isVoipNotificationSilent();
  }

  static void setVoipNotificationSilent(
      bool isSilent,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setVoipNotificationSilent(isSilent, successCallback, errorCallback);
  }

  static Future<bool> isEnableSyncDraft() async {
    return ImclientPlatform.instance.isEnableSyncDraft();
  }

  static void setEnableSyncDraft(
      bool enable,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setEnableSyncDraft(enable, successCallback, errorCallback);
  }

  ///获取免打扰时间段
  static void getNoDisturbingTimes(
      OperationSuccessIntPairCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.getNoDisturbingTimes(successCallback, errorCallback);
  }

  ///设置免打扰时间段
  static void setNoDisturbingTimes(
      int startMins,
      int endMins,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setNoDisturbingTimes(startMins, endMins, successCallback, errorCallback);
  }

  ///取消免打扰时间段
  static void clearNoDisturbingTimes(
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.clearNoDisturbingTimes(successCallback, errorCallback);
  }

  static Future<bool> isNoDisturbing() async {
    return await ImclientPlatform.instance.isNoDisturbing();
  }

  ///是否推送隐藏详情
  static Future<bool> isHiddenNotificationDetail() async {
    return ImclientPlatform.instance.isHiddenNotificationDetail();
  }

  ///设置推送隐藏详情
  static void setHiddenNotificationDetail(
      bool isHidden,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setHiddenNotificationDetail(isHidden, successCallback, errorCallback);
  }

  ///是否群组隐藏用户名
  static Future<bool> isHiddenGroupMemberName(String groupId) async {
    return ImclientPlatform.instance.isHiddenGroupMemberName(groupId);
  }

  ///设置是否群组隐藏用户名
  static void setHiddenGroupMemberName(
      String groupId,
      bool isHidden,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setHiddenGroupMemberName(groupId, isHidden, successCallback, errorCallback);
  }

  static void getMyGroups(
      OperationSuccessStringListCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.getMyGroups(successCallback, errorCallback);
  }

  static void getCommonGroups(String userId,
      OperationSuccessStringListCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.getCommonGroups(userId, successCallback, errorCallback);
  }


  ///设置当前用户是否启用回执功能，仅当服务支持回执功能有效
  static void setUserEnableReceipt(
      bool isEnable,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setUserEnableReceipt(isEnable, successCallback, errorCallback);
  }

  ///获取收藏好友列表
  static Future<List<String>?> getFavUsers() async {
    return ImclientPlatform.instance.getFavUsers();
  }

  ///是否是收藏用户
  static Future<bool> isFavUser(String userId) async {
    return ImclientPlatform.instance.isFavUser(userId);
  }

  ///设置收藏用户
  static void setFavUser(
      String userId,
      bool isFav,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setFavUser(userId, isFav, successCallback, errorCallback);
  }

  ///加入聊天室
  static void joinChatroom(
      String chatroomId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.joinChatroom(chatroomId, successCallback, errorCallback);
  }

  ///退出聊天室
  static void quitChatroom(
      String chatroomId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.quitChatroom(chatroomId, successCallback, errorCallback);
  }

  ///获取聊天室信息
  static void getChatroomInfo(
      String chatroomId,
      int updateDt,
      OperationSuccessChatroomInfoCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.getChatroomInfo(chatroomId, updateDt, successCallback, errorCallback);
  }

  ///获取聊天室成员信息
  static void getChatroomMemberInfo(
      String chatroomId,
      OperationSuccessChatroomMemberInfoCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.getChatroomMemberInfo(chatroomId, successCallback, errorCallback);
  }

  ///获取当前加入聊天室的ID
  static Future<String> getJoinedChatroomId() {
    return ImclientPlatform.instance.getJoinedChatroomId();
  }

  ///创建频道
  static void createChannel(
      String channelName,
      String channelPortrait,
      String desc,
      String extra,
      OperationSuccessChannelInfoCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.createChannel(channelName, channelPortrait, desc, extra, successCallback, errorCallback);
  }

  ///获取频道信息
  static Future<ChannelInfo?> getChannelInfo(String channelId,
      {bool refresh = false}) async {
    return ImclientPlatform.instance.getChannelInfo(channelId, refresh: refresh);
  }

  ///修改频道信息
  static void modifyChannelInfo(
      String channelId,
      ModifyChannelInfoType modifyType,
      String newValue,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.modifyChannelInfo(channelId, modifyType, newValue, successCallback, errorCallback);
  }

  ///搜索频道
  static void searchChannel(
      String keyword,
      OperationSuccessChannelInfosCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.searchChannel(keyword, successCallback, errorCallback);
  }

  ///是否是已订阅频道
  static Future<bool> isListenedChannel(String channelId) async {
    return ImclientPlatform.instance.isListenedChannel(channelId);
  }

  ///订阅/取消订阅频道
  static void listenChannel(
      String channelId,
      bool isListen,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.listenChannel(channelId, isListen, successCallback, errorCallback);
  }

  ///获取我的频道
  static Future<List<String>?> getMyChannels() async {
    return ImclientPlatform.instance.getMyChannels();
  }

  ///获取我订阅的频道
  static void getRemoteListenedChannels(OperationSuccessStringListCallback successCallback, OperationFailureCallback errorCallback) async {
    ImclientPlatform.instance.getRemoteListenedChannels(successCallback, errorCallback);
  }

  ///销毁频道
  static void destroyChannel(
      String channelId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.destroyChannel(channelId, successCallback, errorCallback);
  }

  ///获取PC端在线状态
  static Future<List<PCOnlineInfo>> getOnlineInfos() async {
    return ImclientPlatform.instance.getOnlineInfos();
  }

  ///踢掉PC客户端
  static void kickoffPCClient(
      String clientId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.kickoffPCClient(clientId, successCallback, errorCallback);
  }

  ///是否设置当PC在线时停止手机通知
  static Future<bool> isMuteNotificationWhenPcOnline() async {
    return ImclientPlatform.instance.isMuteNotificationWhenPcOnline();
  }

  ///设置PC/Web在线时，手机是否默认静音。缺省值为YES，只有在IM服务配置server.mobile_default_silent_when_pc_online 为false时，才需要调用此函数设置为NO，此时静音状态意义翻转。其它请求千万不要调用此函数，否则会引起状态错乱。
  ///设置当PC在线时是否通知的方法是 muteNotificationWhenPcOnline:success:error
  static void setDefaultSilentWhenPcOnline(bool defaultSilent) async {
    return ImclientPlatform.instance.setDefaultSilentWhenPcOnline(defaultSilent);
  }

  ///设置/取消设置当PC在线时停止手机通知
  static void muteNotificationWhenPcOnline(
      bool isMute,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.muteNotificationWhenPcOnline(isMute, successCallback, errorCallback);
  }

  ///获取用户的在线状态
  static Future<UserOnlineState?> getUserOnlineState(String userId) async {
    return ImclientPlatform.instance.getUserOnlineState(userId);
  }

  ///获取当前用户的自定义状态
  static Future<CustomState> getMyCustomState() async {
    return ImclientPlatform.instance.getMyCustomState();
  }

  ///设置当前用户的自定义状态
  static void setMyCustomState(
      int customState, String? customText,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.setMyCustomState(customState, customText, successCallback, errorCallback);
  }

  ///订阅对象的用户在线状态
  static void watchOnlineState(
      ConversationType conversationType, List<String> targets, int watchDuration,
      OperationSuccessWatchUserOnlineCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.watchOnlineState(conversationType, targets, watchDuration, successCallback, errorCallback);
  }

  ///取消订阅对象的用户在线状态
  static void unwatchOnlineState(
      ConversationType conversationType, List<String> targets,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.unwatchOnlineState(conversationType, targets, successCallback, errorCallback);
  }

  ///服务是否开启用户在线状态
  static Future<bool> isEnableUserOnlineState() async {
    return ImclientPlatform.instance.isEnableUserOnlineState();
  }

  ///获取会话文件记录
  static void getConversationFiles(
      int beforeMessageUid,
      FileRecordOrder order,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback,
      {Conversation? conversation,
        String? fromUser}) {
    ImclientPlatform.instance.getConversationFiles(beforeMessageUid, order, count, successCallback, errorCallback, conversation: conversation, fromUser: fromUser);
  }

  ///获取我的文件记录
  static void getMyFiles(
      int beforeMessageUid,
      FileRecordOrder order,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.getMyFiles(beforeMessageUid, order, count, successCallback, errorCallback);
  }

  ///删除文件记录
  static void deleteFileRecord(
      int messageUid,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.deleteFileRecord(messageUid, successCallback, errorCallback);
  }

  ///搜索文件记录
  static void searchFiles(
      String keyword,
      int beforeMessageUid,
      FileRecordOrder order,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback,
      {Conversation? conversation,
        String? fromUser}) {
    ImclientPlatform.instance.searchFiles(keyword, beforeMessageUid, order, count, successCallback, errorCallback, conversation: conversation, fromUser: fromUser);
  }

  ///搜索我的文件记录
  static void searchMyFiles(
      String keyword,
      int beforeMessageUid,
      FileRecordOrder order,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.searchMyFiles(keyword, beforeMessageUid, order, count, successCallback, errorCallback);
  }

  ///获取经过授权的媒体路径
  static void getAuthorizedMediaUrl(
      String mediaPath,
      int messageUid,
      int mediaType,
      OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.getAuthorizedMediaUrl(mediaPath, messageUid, mediaType, successCallback, errorCallback);
  }

  static void getAuthCode(
      String applicationId,
      int type,
      String host,
      OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.getAuthCode(applicationId, type, host, successCallback, errorCallback);
  }

  static void configApplication(
      String applicationId,
      int type,
      int timestamp,
      String nonce,
      String signature,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    ImclientPlatform.instance.configApplication(applicationId, type, timestamp, nonce, signature, successCallback, errorCallback);
  }

  ///转换amr数据为wav数据，仅在iOS平台有效
  static Future<Uint8List> getWavData(String amrPath) async {
    return ImclientPlatform.instance.getWavData(amrPath);
  }

  ///开启协议栈数据库事物，仅当数据迁移功能使用
  static Future<bool> beginTransaction() async {
    return ImclientPlatform.instance.beginTransaction();
  }

  ///提交协议栈数据库事物，仅当数据迁移功能使用
  static Future<bool> commitTransaction() async {
    return ImclientPlatform.instance.commitTransaction();
  }

  ///提交协议栈数据库事物，仅当数据迁移功能使用
  static Future<bool> rollbackTransaction() async {
    return ImclientPlatform.instance.rollbackTransaction();
  }


  ///是否是专业版
  static Future<bool> isCommercialServer() async {
    return ImclientPlatform.instance.isCommercialServer();
  }

  ///服务是否支持消息回执
  static Future<bool> isReceiptEnabled() async {
    return ImclientPlatform.instance.isReceiptEnabled();
  }

  ///当前用户是否启用回执功能
  static Future<bool> isUserEnableReceipt() async {
    return ImclientPlatform.instance.isUserEnableReceipt();
  }

  ///服务是否支持群组消息回执
  static Future<bool> isGroupReceiptEnabled() async {
    return ImclientPlatform.instance.isGroupReceiptEnabled();
  }

  static Future<bool> isGlobalDisableSyncDraft() async {
    return ImclientPlatform.instance.isGlobalDisableSyncDraft();
  }
}
