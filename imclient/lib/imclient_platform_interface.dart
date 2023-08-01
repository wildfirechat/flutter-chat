import 'package:event_bus/event_bus.dart';
import 'package:flutter/services.dart';
import 'package:imclient/model/friend.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'imclient.dart';
import 'imclient_method_channel.dart';
import 'message/message.dart';
import 'message/message_content.dart';
import 'model/channel_info.dart';
import 'model/conversation.dart';
import 'model/conversation_info.dart';
import 'model/conversation_search_info.dart';
import 'model/friend_request.dart';
import 'model/group_info.dart';
import 'model/group_member.dart';
import 'model/group_search_info.dart';
import 'model/im_constant.dart';
import 'model/message_payload.dart';
import 'model/online_info.dart';
import 'model/unread_count.dart';
import 'model/user_info.dart';

abstract class ImclientPlatform extends PlatformInterface {
  /// Constructs a ImclientPlatform.
  ImclientPlatform() : super(token: _token);

  static final Object _token = Object();

  static ImclientPlatform _instance = MethodChannelImclient();

  /// The default instance of [ImclientPlatform] to use.
  ///
  /// Defaults to [MethodChannelImclient].
  static ImclientPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ImclientPlatform] when
  /// they register themselves.
  static set instance(ImclientPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  EventBus get IMEventBus {
    throw UnimplementedError('method has not been implemented.');
  }

  ///客户端ID，客户端的唯一标示。获取IM Token时必须带上正确的客户端ID，否则会无法连接成功。
  Future<String> get clientId async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///客户端是否调用过connect
  Future<bool> get isLogined async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///连接状态
  Future<int> get connectionStatus async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///当前用户ID
  Future<String> get currentUserId async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///当前服务器与客户端时间的差值，单位是毫秒，只能是初略估计，不精确。
  Future<int> get serverDeltaTime async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///开启协议栈日志
  Future<void> startLog() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///结束协议栈日志
  Future<void> stopLog() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置发送日志命令
  Future<void> setSendLogCommand(String sendLogCmd) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<void> useSM4() async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<void> setLiteMode(bool liteMode) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<void> setDeviceToken(int pushType, String deviceToken) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<void> setVoipDeviceToken(String voipToken) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<void> setBackupAddressStrategy(int strategy) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<void> setBackupAddress(String host, int port) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<void> setProtoUserAgent(String agent) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<void> addHttpHeader(String header, String value) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<void> setProxyInfo(String host, String ip, int port, {String? userName, String? password}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<String> get protoRevision async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取协议栈日志文件路径
  Future<List<String>> get logFilesPath async {
    throw UnimplementedError('method has not been implemented.');
  }

  void init(
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
        ChannelInfoUpdatedCallback? channelInfoUpdatedCallback}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  void registerMessage(MessageContentMeta contentMeta) {
    throw UnimplementedError('method has not been implemented.');
  }

  /// 连接IM服务。调用连接之后才可以调用获取数据接口。连接状态会通过连接状态回调返回。
  /// [host]为IM服务域名或IP，必须im.example.com或114.144.114.144，不带http头和端口。
  Future<int> connect(String host, String userId, String token) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///断开IM服务连接。
  /// * disablePush 是否继续接受推送。
  /// * clearSession 是否清除session
  Future<void> disconnect(
      {bool disablePush = false, bool clearSession = false}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取会话列表
  Future<List<ConversationInfo>> getConversationInfos(
      List<ConversationType> types, List<int> lines) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取会话信息
  Future<ConversationInfo> getConversationInfo(
      Conversation conversation) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///搜索会话信息
  Future<List<ConversationSearchInfo>> searchConversation(
      String keyword, List<ConversationType> types, List<int> lines) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///移除会话
  Future<void> removeConversation(
      Conversation conversation, bool clearMessage) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置/取消会话置顶
  void setConversationTop(
      Conversation conversation,
      bool isTop,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置/取消会话免到扰
  void setConversationSilent(
      Conversation conversation,
      bool isSilent,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///保存草稿
  Future<void> setConversationDraft(
      Conversation conversation, String draft) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置会话时间戳
  Future<void> setConversationTimestamp(
      Conversation conversation, int timestamp) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置会话中第一个未读消息ID
  Future<int> getFirstUnreadMessageId(Conversation conversation) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置会话未读状态
  Future<UnreadCount> getConversationUnreadCount(
      Conversation conversation) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置某些类型会话未读状态
  Future<UnreadCount> getConversationsUnreadCount(
      List<ConversationType> types, List<int> lines) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///清除一个会话的未读状态
  Future<bool> clearConversationUnreadStatus(
      Conversation conversation) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///清除某些类型会话的未读状态
  Future<bool> clearConversationsUnreadStatus(
      List<ConversationType> types, List<int> lines) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<bool> clearMessageUnreadStatus(int messageId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<bool> markAsUnRead(Conversation conversation, bool sync) async {
    throw UnimplementedError('method has not been implemented.');
  }


  ///获取会话的已读状态
  Future<Map<String, int>> getConversationRead(
      Conversation conversation) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取会话的消息送达状态
  Future<Map<String, int>> getMessageDelivery(
      Conversation conversation) async {
    throw UnimplementedError('method has not been implemented.');
  }

  MessageContent decodeMessageContent(MessagePayload payload) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取会话的消息列表
  Future<List<Message>> getMessages(
      Conversation conversation, int fromIndex, int count,
      {List<int>? contentTypes, String? withUser}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///根据消息状态获取会话的消息列表
  Future<List<Message>> getMessagesByStatus(Conversation conversation,
      int fromIndex, int count, List<MessageStatus> messageStatus,
      {String? withUser}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取某些类型会话的消息列表
  Future<List<Message>> getConversationsMessages(
      List<ConversationType> types, List<int> lines, int fromIndex, int count,
      {List<int>? contentTypes, String? withUser}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///根据消息状态获取某些类型会话的消息列表
  Future<List<Message>> getConversationsMessageByStatus(
      List<ConversationType> types,
      List<int> lines,
      int fromIndex,
      int count,
      List<MessageStatus> messageStatus,
      {String? withUser}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取远端历史消息
  void getRemoteMessages(
      Conversation conversation,
      int beforeMessageUid,
      int count,
      OperationSuccessMessagesCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? contentTypes}) {
    throw UnimplementedError('method has not been implemented.');
  }

  void getRemoteMessage(
      int messageUid,
      OperationSuccessMessageCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///根据消息Id获取消息
  Future<Message?> getMessage(int messageId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///根据消息Uid获取消息
  Future<Message?> getMessageByUid(int messageUid) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///搜索某个会话内消息
  Future<List<Message>> searchMessages(Conversation conversation,
      String keyword, bool order, int limit, int offset) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///搜索某些类会话内消息
  Future<List<Message>> searchConversationsMessages(
      List<ConversationType> types,
      List<int> lines,
      String keyword,
      int fromIndex,
      int count, {
        List<int>? contentTypes,
      }) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///发送媒体类型消息
  Future<Message> sendMediaMessage(
      Conversation conversation, MessageContent content,
      {List<String>? toUsers,
        int expireDuration = 0,
        required SendMessageSuccessCallback successCallback,
        required OperationFailureCallback errorCallback,
        SendMediaMessageProgressCallback? progressCallback,
        SendMediaMessageUploadedCallback? uploadedCallback}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///发送已保存消息
  Future<bool> sendSavedMessage(int messageId,
      {int expireDuration = 0,
        required SendMessageSuccessCallback successCallback,
        required OperationFailureCallback errorCallback}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<bool> cancelSendingMessage(int messageId) async {
    throw UnimplementedError('method has not been implemented.');
  }



  ///撤回消息
  void recallMessage(
      int messageUid,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///上传媒体数据
  void uploadMedia(
      String fileName,
      Uint8List mediaData,
      int mediaType,
      OperationSuccessStringCallback successCallback,
      SendMediaMessageProgressCallback progressCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  void getMediaUploadUrl(
      String fileName,
      int mediaType,
      String contentType,
      GetUploadUrlSuccessCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<bool> isSupportBigFilesUpload() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///删除消息
  Future<bool> deleteMessage(int messageId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<bool> batchDeleteMessages(List<int> messageUids) async {
    throw UnimplementedError('method has not been implemented.');
  }

  void deleteRemoteMessage(
      int messageUid,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }


  ///清空会话内消息
  Future<bool> clearMessages(Conversation conversation,
      {int before = 0}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  void clearRemoteConversationMessage(Conversation conversation,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置消息已经播放
  Future<void> setMediaMessagePlayed(int messageId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<bool> setMessageLocalExtra(int messageId, String localExtra) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///插入消息
  Future<Message> insertMessage(Conversation conversation, String sender,
      MessageContent content, int status, int serverTime, {List<String>? toUsers}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///更新消息内容
  Future<void> updateMessage(
      int messageId, MessageContent content) async {
    throw UnimplementedError('method has not been implemented.');
  }

  void updateRemoteMessageContent(
      int messageUid, MessageContent content, bool distribute, bool updateLocal,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///更新消息状态
  Future<void> updateMessageStatus(
      int messageId, MessageStatus status) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取会话内消息数量
  Future<int> getMessageCount(Conversation conversation) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取用户信息
  Future<UserInfo?> getUserInfo(String userId,
      {String? groupId, bool refresh = false}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///批量获取用户信息
  Future<List<UserInfo>> getUserInfos(List<String> userIds,
      {String? groupId}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///搜索用户
  void searchUser(
      String keyword,
      int searchType,
      int page,
      OperationSuccessUserInfosCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///异步获取用户信息
  void getUserInfoAsync(
      String userId,
      OperationSuccessUserInfoCallback successCallback,
      OperationFailureCallback errorCallback,
      {bool refresh = false}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///是否是好友
  Future<bool> isMyFriend(String userId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取好友列表
  Future<List<String>> getMyFriendList({bool refresh = false}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///搜索好友
  Future<List<UserInfo>> searchFriends(String keyword) async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<List<Friend>> getFriends(bool refresh) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///搜索群组
  Future<List<GroupSearchInfo>> searchGroups(String keyword) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取收到的好友请求列表
  Future<List<FriendRequest>> getIncommingFriendRequest() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取发出去的好友请求列表
  Future<List<FriendRequest>> getOutgoingFriendRequest() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取某个用户相关的好友请求
  Future<FriendRequest?> getFriendRequest(
      String userId, FriendRequestDirection direction) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///同步远程好友请求信息
  Future<void> loadFriendRequestFromRemote() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取未读好友请求数
  Future<int> getUnreadFriendRequestStatus() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///清除未读好友请求计数
  Future<bool> clearUnreadFriendRequestStatus() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///删除好友
  void deleteFriend(
      String userId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///发送好友请求
  void sendFriendRequest(
      String userId,
      String reason,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///处理好友请求
  void handleFriendRequest(
      String userId,
      bool accept,
      String extra,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取好友备注名
  Future<String?> getFriendAlias(String userId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置好友备注名
  void setFriendAlias(
      String friendId,
      String? alias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取好友extra信息
  Future<String> getFriendExtra(String userId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///是否是黑名单用户
  Future<bool> isBlackListed(String userId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取黑名单列表
  Future<List<String>> getBlackList({bool refresh = false}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置/取消用户黑名单
  void setBlackList(
      String userId,
      bool isBlackListed,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取群成员列表
  Future<List<GroupMember>> getGroupMembers(String groupId,
      {bool refresh = false}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取群成员列表
  Future<List<GroupMember>> getGroupMembersByCount(String groupId, int count) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///根据群成员类型获取群成员列表
  Future<List<GroupMember>> getGroupMembersByTypes(
      String groupId, GroupMemberType memberType) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///异步获取群成员列表
  void getGroupMembersAsync(String groupId,
      {bool refresh = false,
        required OperationSuccessGroupMembersCallback successCallback,
        required OperationFailureCallback errorCallback}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取群信息
  Future<GroupInfo?> getGroupInfo(String groupId,
      {bool refresh = false}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///异步获取群信息
  void getGroupInfoAsync(String groupId,
      {bool refresh = false,
        required OperationSuccessGroupInfoCallback successCallback,
        required OperationFailureCallback errorCallback}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取单个群成员信息
  Future<GroupMember?> getGroupMember(
      String groupId, String memberId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///创建群组，groupId可以为空。
  void createGroup(
      String? groupId,
      String? groupName,
      String? groupPortrait,
      int type,
      List<String> members,
      OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///添加群成员
  void addGroupMembers(
      String groupId,
      List<String> members,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///移除群成员
  void kickoffGroupMembers(
      String groupId,
      List<String> members,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///退出群组
  void quitGroup(
      String groupId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///解散群组
  void dismissGroup(
      String groupId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///修改群组信息
  void modifyGroupInfo(
      String groupId,
      ModifyGroupInfoType modifyType,
      String newValue,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///修改自己的群名片
  void modifyGroupAlias(
      String groupId,
      String newAlias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///修改群成员的群名片
  void modifyGroupMemberAlias(
      String groupId,
      String memberId,
      String newAlias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///转移群组
  void transferGroup(
      String groupId,
      String newOwner,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置/取消群管理员
  void setGroupManager(
      String groupId,
      bool isSet,
      List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///禁言/取消禁言群成员
  void muteGroupMember(
      String groupId,
      bool isSet,
      List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置/取消群白名单
  void allowGroupMember(
      String groupId,
      bool isSet,
      List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<String> getGroupRemark(String groupId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  void setGroupRemark(String groupId, String remark,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取收藏群组列表
  Future<List<String>?> getFavGroups() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///是否收藏群组
  Future<bool> isFavGroup(String groupId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置/取消收藏群组
  void setFavGroup(
      String groupId,
      bool isFav,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取用户设置
  Future<String> getUserSetting(int scope, String value) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取某类用户设置
  Future<Map<String, String>> getUserSettings(int scope) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置用户设置
  void setUserSetting(
      int scope,
      String key,
      String value,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///修改当前用户信息
  void modifyMyInfo(
      Map<ModifyMyInfoType, String> values,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///是否全局静音
  Future<bool> isGlobalSilent() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置/取消全局静音
  void setGlobalSilent(
      bool isSilent,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<bool> isVoipNotificationSilent() async {
    throw UnimplementedError('method has not been implemented.');
  }

  void setVoipNotificationSilent(
      bool isSilent,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<bool> isEnableSyncDraft() async {
    throw UnimplementedError('method has not been implemented.');
  }

  void setEnableSyncDraft(
      bool enable,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }


  ///获取免打扰时间段
  void getNoDisturbingTimes(
      OperationSuccessIntPairCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置免打扰时间段
  void setNoDisturbingTimes(
      int startMins,
      int endMins,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///取消免打扰时间段
  void clearNoDisturbingTimes(
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<bool> isNoDisturbing() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///是否推送隐藏详情
  Future<bool> isHiddenNotificationDetail() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置推送隐藏详情
  void setHiddenNotificationDetail(
      bool isHidden,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///是否群组隐藏用户名
  Future<bool> isHiddenGroupMemberName(String groupId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置是否群组隐藏用户名
  void setHiddenGroupMemberName(
      bool isHidden,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  void getMyGroups(
      OperationSuccessStringListCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  void getCommonGroups(String userId,
      OperationSuccessStringListCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///当前用户是否启用回执功能
  Future<bool> isUserEnableReceipt() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置当前用户是否启用回执功能，仅当服务支持回执功能有效
  void setUserEnableReceipt(
      bool isEnable,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取收藏好友列表
  Future<List<String>?> getFavUsers() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///是否是收藏用户
  Future<bool> isFavUser(String userId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置收藏用户
  void setFavUser(
      String userId,
      bool isFav,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///加入聊天室
  void joinChatroom(
      String chatroomId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///退出聊天室
  void quitChatroom(
      String chatroomId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取聊天室信息
  void getChatroomInfo(
      String chatroomId,
      int updateDt,
      OperationSuccessChatroomInfoCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取聊天室成员信息
  void getChatroomMemberInfo(
      String chatroomId,
      OperationSuccessChatroomMemberInfoCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///创建频道
  void createChannel(
      String channelName,
      String channelPortrait,
      int status,
      String desc,
      String extra,
      OperationSuccessChannelInfoCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取频道信息
  Future<ChannelInfo?> getChannelInfo(String channelId,
      {bool refresh = false}) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///修改频道信息
  void modifyChannelInfo(
      String channelId,
      ModifyChannelInfoType modifyType,
      String newValue,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///搜索频道
  void searchChannel(
      String keyword,
      OperationSuccessChannelInfosCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///是否是已订阅频道
  Future<bool> isListenedChannel(String channelId) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///订阅/取消订阅频道
  void listenChannel(
      String channelId,
      bool isListen,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取我的频道
  Future<List<String>?> getMyChannels() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取我订阅的频道
  Future<List<String>?> getListenedChannels() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///销毁频道
  void destroyChannel(
      String channelId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取PC端在线状态
  Future<List<OnlineInfo>> getOnlineInfos() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///踢掉PC客户端
  void kickoffPCClient(
      String clientId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///是否设置当PC在线时停止手机通知
  Future<bool> isMuteNotificationWhenPcOnline() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///设置/取消设置当PC在线时停止手机通知
  void muteNotificationWhenPcOnline(
      bool isMute,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取会话文件记录
  void getConversationFiles(
      int beforeMessageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback,
      {Conversation? conversation,
        String? fromUser}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取我的文件记录
  void getMyFiles(
      int beforeMessageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///删除文件记录
  void deleteFileRecord(
      int messageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///搜索文件记录
  void searchFiles(
      String keyword,
      int beforeMessageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback,
      {Conversation? conversation,
        String? fromUser}) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///搜索我的文件记录
  void searchMyFiles(
      String keyword,
      int beforeMessageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///获取经过授权的媒体路径
  void getAuthorizedMediaUrl(
      String mediaPath,
      int messageUid,
      int mediaType,
      OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  void getAuthCode(
      String applicationId,
      int type,
      String host,
      OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  void configApplication(
      String applicationId,
      int type,
      int timestamp,
      String nonce,
      String signature,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    throw UnimplementedError('method has not been implemented.');
  }

  ///转换amr数据为wav数据，仅在iOS平台有效
  Future<Uint8List> getWavData(String amrPath) async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///开启协议栈数据库事物，仅当数据迁移功能使用
  Future<bool> beginTransaction() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///提交协议栈数据库事物，仅当数据迁移功能使用
  Future<bool> commitTransaction() async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<bool> rollbackTransaction() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///是否是专业版
  Future<bool> isCommercialServer() async {
    throw UnimplementedError('method has not been implemented.');
  }

  ///服务是否支持消息回执
  Future<bool> isReceiptEnabled() async {
    throw UnimplementedError('method has not been implemented.');
  }

  Future<bool> isGlobalDisableSyncDraft() async {
    throw UnimplementedError('method has not been implemented.');
  }

}
