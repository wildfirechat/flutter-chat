import 'dart:async';
import 'dart:js_util' as js_util;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/conversation_search_info.dart';
import 'package:imclient/model/friend.dart';
import 'package:imclient/model/friend_request.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/pc_online_info.dart';
import 'package:imclient/model/read_report.dart';
import 'package:imclient/model/unread_count.dart';
import 'package:imclient/model/user_info.dart';
import 'package:imclient/model/user_online_state.dart';

import 'imclient_method_channel.dart';

/// Web implementation of [ImclientPlatform] using the WildFireChat Web SDK.
class ImclientWeb extends ImclientPlatform {
  ImclientWeb() : super();

  static void registerWith(Registrar registrar) {
    ImclientPlatform.instance = ImclientWeb();
  }

  Object? get _wfc {
    try {
      return js_util.getProperty(js_util.globalThis, 'wfc');
    } catch (e) {
      return null;
    }
  }

  Object? _call(String method, [List<dynamic>? args]) {
    final wfc = _wfc;
    if (wfc == null) {
      throw MissingPluginException('wfc SDK not loaded');
    }
    return js_util.callMethod(wfc, method, args ?? []);
  }

  Object? _getProperty(String name) {
    final wfc = _wfc;
    if (wfc == null) return null;
    return js_util.getProperty(wfc, name);
  }

  static int _requestId = 0;
  static final Map<int, SendMessageSuccessCallback> _sendMessageSuccessCallbackMap = {};
  static final Map<int, OperationFailureCallback> _errorCallbackMap = {};
  static final Map<int, SendMediaMessageProgressCallback> _sendMediaMessageProgressCallbackMap = {};
  static final Map<int, SendMediaMessageUploadedCallback> _sendMediaMessageUploadedCallbackMap = {};
  static final Map<int, Message> _sendingMessages = {};

  static final Map<String, UserOnlineState> _useOnlineCacheMap = {};

  ConnectionStatusChangedCallback? _connectionStatusChangedCallback;
  ReceiveMessageCallback? _receiveMessageCallback;
  RecallMessageCallback? _recallMessageCallback;
  DeleteMessageCallback? _deleteMessageCallback;
  MessageDeliveriedCallback? _messageDeliveriedCallback;
  MessageReadedCallback? _messageReadedCallback;
  GroupInfoUpdatedCallback? _groupInfoUpdatedCallback;
  GroupMemberUpdatedCallback? _groupMemberUpdatedCallback;
  UserInfoUpdatedCallback? _userInfoUpdatedCallback;
  FriendListUpdatedCallback? _friendListUpdatedCallback;
  FriendRequestListUpdatedCallback? _friendRequestListUpdatedCallback;
  UserSettingsUpdatedCallback? _userSettingsUpdatedCallback;
  ChannelInfoUpdatedCallback? _channelInfoUpdatedCallback;
  OnlineEventCallback? _onlineEventCallback;

  bool _initialized = false;

  @override
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
      ChannelInfoUpdatedCallback? channelInfoUpdatedCallback,
      OnlineEventCallback? onlineEventCallback}) {
    _connectionStatusChangedCallback = connectionStatusChangedCallback;
    _receiveMessageCallback = receiveMessageCallback;
    _recallMessageCallback = recallMessageCallback;
    _deleteMessageCallback = deleteMessageCallback;
    _messageDeliveriedCallback = messageDeliveriedCallback;
    _messageReadedCallback = messageReadedCallback;
    _groupInfoUpdatedCallback = groupInfoUpdatedCallback;
    _groupMemberUpdatedCallback = groupMemberUpdatedCallback;
    _userInfoUpdatedCallback = userInfoUpdatedCallback;
    _friendListUpdatedCallback = friendListUpdatedCallback;
    _friendRequestListUpdatedCallback = friendRequestListUpdatedCallback;
    _userSettingsUpdatedCallback = userSettingsUpdatedCallback;
    _channelInfoUpdatedCallback = channelInfoUpdatedCallback;
    _onlineEventCallback = onlineEventCallback;

    final eventEmitter = _getProperty('eventEmitter');
    if (eventEmitter != null) {
      _on(eventEmitter, 'connectionStatusChanged', _jsConnectionStatusChanged);
      _on(eventEmitter, 'receiveMsg', _jsReceiveMessage);
      _on(eventEmitter, 'recallMsg', _jsRecallMessage);
      _on(eventEmitter, 'deleteMsg', _jsDeleteMessage);
      _on(eventEmitter, 'msgReceived', _jsMessageDelivered);
      _on(eventEmitter, 'msgRead', _jsMessageReaded);
      _on(eventEmitter, 'msgStatusUpdate', _jsMessageStatusUpdate);
      _on(eventEmitter, 'userInfosUpdate', _jsUserInfoUpdated);
      _on(eventEmitter, 'groupInfosUpdate', _jsGroupInfoUpdated);
      _on(eventEmitter, 'groupMembersUpdate', _jsGroupMemberUpdated);
      _on(eventEmitter, 'friendListUpdate', _jsFriendListUpdated);
      _on(eventEmitter, 'friendRequestUpdate', _jsFriendRequestUpdated);
      _on(eventEmitter, 'settingUpdate', _jsSettingUpdated);
      _on(eventEmitter, 'channelInfosUpdate', _jsChannelInfoUpdated);
      _on(eventEmitter, 'onlineEvent', _jsUserOnlineEvent);
      _on(eventEmitter, 'conversationInfoUpdate', _jsConversationInfoUpdate);
    }

    _call('init');
    _initialized = true;
  }

  @override
  void registerMessage(MessageContentMeta contentMeta) {
    // Web SDK message content types are registered in JavaScript; no-op for web.
  }

  void _on(Object emitter, String event, Function handler) {
    js_util.callMethod(emitter, 'on', [event, js_util.allowInterop(handler)]);
  }

  void _jsConnectionStatusChanged(dynamic status) {
    final s = status is num ? status.toInt() : 0;
    _connectionStatusChangedCallback?.call(s);
    IMEventBus.fire(ConnectionStatusChangedEvent(s));
  }

  void _jsReceiveMessage(dynamic messages, [dynamic hasMore]) {
    final list = messages as List?;
    if (list == null) return;
    final bool more = hasMore == true || (hasMore is num && hasMore != 0);
    final msgs = ImclientPlatform.convertProtoMessages(list);
    if (msgs.isNotEmpty) {
      _receiveMessageCallback?.call(msgs, more);
      IMEventBus.fire(ReceiveMessagesEvent(msgs, more));
    }
  }

  void _jsRecallMessage(dynamic operator, dynamic messageUid) {
    final uid = _toInt(messageUid);
    if (uid == null) return;
    _recallMessageCallback?.call(uid);
    Future(() async {
      final msg = await getMessageByUid(uid);
      if (msg != null) {
        IMEventBus.fire(RecallMessageEvent(uid, conversation: msg.conversation));
      }
    });
  }

  void _jsDeleteMessage(dynamic messageUid) {
    final uid = _toInt(messageUid);
    if (uid == null) return;
    _deleteMessageCallback?.call(uid);
    Future(() async {
      final msg = await getMessageByUid(uid);
      if (msg != null) {
        IMEventBus.fire(DeleteMessageEvent(messageUid: uid, conversation: msg.conversation));
      }
    });
  }

  void _jsMessageDelivered(dynamic deliveryMap) {
    if (deliveryMap is! Map) return;
    final Map<String, int> data = {};
    deliveryMap.forEach((key, value) {
      data[key.toString()] = _toInt(value) ?? 0;
    });
    _messageDeliveriedCallback?.call(data);
    IMEventBus.fire(MessageDeliveriedEvent(data));
  }

  void _jsMessageReaded(dynamic readEntries) {
    if (readEntries is! List) return;
    final reports = <ReadReport>[];
    for (final entry in readEntries) {
      final report = ImclientPlatform.convertProtoReadEntry(entry as Map?);
      if (report != null) reports.add(report);
    }
    _messageReadedCallback?.call(reports);
    IMEventBus.fire(MessageReadedEvent(reports));
  }

  void _jsMessageStatusUpdate(dynamic message) {
    final msg = ImclientPlatform.convertProtoMessage(message as Map?);
    if (msg != null) {
      IMEventBus.fire(MessageUpdatedEvent(msg.messageId));
    }
  }

  void _jsUserInfoUpdated(dynamic users) {
    if (users is! List) return;
    final infos = <UserInfo>[];
    for (final u in users) {
      final info = ImclientPlatform.convertProtoUserInfo(u as Map?);
      if (info != null) infos.add(info);
    }
    _userInfoUpdatedCallback?.call(infos);
    IMEventBus.fire(UserInfoUpdatedEvent(infos));
  }

  void _jsGroupInfoUpdated(dynamic groups) {
    if (groups is! List) return;
    Future(() async {
      final infos = <GroupInfo>[];
      for (final g in groups) {
        final info = await ImclientPlatform.convertProtoGroupInfo(g as Map?);
        if (info != null) infos.add(info);
      }
      _groupInfoUpdatedCallback?.call(infos);
      IMEventBus.fire(GroupInfoUpdatedEvent(infos));
    });
  }

  void _jsGroupMemberUpdated(dynamic groupId, dynamic members) {
    if (members is! List) return;
    final list = <GroupMember>[];
    for (final m in members) {
      final member = ImclientPlatform.convertProtoGroupMember(m as Map);
      if (member != null) list.add(member);
    }
    _groupMemberUpdatedCallback?.call(groupId.toString(), list);
    IMEventBus.fire(GroupMembersUpdatedEvent(groupId.toString(), list));
  }

  void _jsFriendListUpdated(dynamic friends) {
    final list = <String>[];
    if (friends is List) {
      for (final f in friends) {
        list.add(f.toString());
      }
    }
    _friendListUpdatedCallback?.call(list);
    IMEventBus.fire(FriendUpdateEvent(list));
  }

  void _jsFriendRequestUpdated(dynamic requests) {
    final list = <String>[];
    if (requests is List) {
      for (final r in requests) {
        if (r is Map && r['target'] != null) {
          list.add(r['target'].toString());
        } else {
          list.add(r.toString());
        }
      }
    }
    _friendRequestListUpdatedCallback?.call(list);
    IMEventBus.fire(FriendRequestUpdateEvent(list));
  }

  void _jsSettingUpdated() {
    _userSettingsUpdatedCallback?.call();
    IMEventBus.fire(UserSettingUpdatedEvent());
  }

  void _jsChannelInfoUpdated(dynamic channels) {
    if (channels is! List) return;
    final infos = <ChannelInfo>[];
    for (final c in channels) {
      final info = ImclientPlatform.convertProtoChannelInfo(c as Map?);
      if (info != null) infos.add(info);
    }
    _channelInfoUpdatedCallback?.call(infos);
    IMEventBus.fire(ChannelInfoUpdateEvent(infos));
  }

  void _jsUserOnlineEvent(dynamic states) {
    if (states is! List) return;
    final infos = <UserOnlineState>[];
    for (final s in states) {
      final info = ImclientPlatform.convertProtoUserOnlineState(s as Map);
      infos.add(info);
      _useOnlineCacheMap[info.userId] = info;
    }
    _onlineEventCallback?.call(infos);
    IMEventBus.fire(UserOnlineStateUpdatedEvent(infos));
  }

  void _jsConversationInfoUpdate(dynamic info) {
    if (info is Map) {
      final convInfo = ImclientPlatform.convertProtoConversationInfo(info);
      IMEventBus.fire(ConversationTopUpdatedEvent(convInfo.conversation, convInfo.isTop));
    }
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  Future<String> get clientId async {
    final result = _call('getClientId');
    return result?.toString() ?? '';
  }

  @override
  Future<bool> get isLogined async {
    final result = _call('isLogin');
    return result == true;
  }

  @override
  Future<int> get connectionStatus async {
    final result = _call('getConnectionStatus');
    return _toInt(result) ?? kConnectionStatusUnconnected;
  }

  @override
  String get currentUserId {
    final result = _call('getUserId');
    return result?.toString() ?? userId;
  }

  @override
  Future<int> get serverDeltaTime async {
    final result = _call('getServerDeltaTime');
    return _toInt(result) ?? 0;
  }

  @override
  Future<String> get protoRevision async {
    final result = _call('getProtoRevision');
    return result?.toString() ?? '';
  }

  @override
  Future<void> startLog() async {}

  @override
  Future<void> stopLog() async {}

  @override
  Future<void> setSendLogCommand(String sendLogCmd) async {}

  @override
  Future<void> useSM4() async {
    _call('useSM4');
  }

  @override
  Future<void> setLiteMode(bool liteMode) async {}

  @override
  Future<void> setDeviceToken(int pushType, String deviceToken) async {}

  @override
  Future<void> setVoipDeviceToken(String voipToken) async {}

  @override
  Future<void> setBackupAddressStrategy(int strategy) async {
    _call('setBackupAddressStrategy', [strategy]);
  }

  @override
  Future<void> setBackupAddress(String host, int port) async {
    _call('setBackupAddress', [host, port]);
  }

  @override
  Future<void> setProtoUserAgent(String agent) async {}

  @override
  Future<void> addHttpHeader(String header, String value) async {}

  @override
  Future<void> setProxyInfo(String host, String ip, int port,
      {String? userName, String? password}) async {}

  @override
  Future<List<String>> get logFilesPath async => [];

  @override
  Future<int> connect(String host, String userId, String token) async {
    if (!_initialized) {
      throw Exception("没有初始化，请在应用启动时，调用imclient的init方法，之后才可以调用connect进行连接。");
    }
    this.userId = userId;
    _call('connect', [userId, token]);
    return 0;
  }

  @override
  Future<void> disconnect(
      {bool disablePush = false, bool clearSession = false}) async {
    _call('disconnect');
  }

  @override
  Future<List<ConversationInfo>> getConversationInfos(
      List<ConversationType> types, List<int> lines) async {
    final typeIndexes = types.map((e) => e.index).toList();
    final result = _call('getConversationList', [typeIndexes, lines.isEmpty ? [0] : lines]);
    if (result is! List) return [];
    return result
        .whereType<Map>()
        .map((e) => ImclientPlatform.convertProtoConversationInfo(e))
        .toList();
  }

  @override
  Future<ConversationInfo> getConversationInfo(Conversation conversation) async {
    final result = _call('getConversationInfo', [_convertConversation(conversation)]);
    if (result is Map) {
      return ImclientPlatform.convertProtoConversationInfo(result);
    }
    final info = ConversationInfo();
    info.conversation = conversation;
    return info;
  }

  @override
  Future<List<ConversationSearchInfo>> searchConversation(
      String keyword, List<ConversationType> types, List<int> lines) async {
    final typeIndexes = types.map((e) => e.index).toList();
    final result = _call('searchConversation', [keyword, typeIndexes, lines.isEmpty ? [0, 1, 2] : lines]);
    if (result is! List) return [];
    return result.whereType<Map>().map((e) {
      final info = ConversationSearchInfo();
      info.conversation = ImclientPlatform.convertProtoConversation(e['conversation'] ?? e);
      info.marchedMessage = ImclientPlatform.convertProtoMessage(e['marchedMessage']);
      info.marchedCount = _toInt(e['marchedCount']) ?? 0;
      info.timestamp = _toInt(e['timestamp']) ?? 0;
      info.keyword = keyword;
      return info;
    }).toList();
  }

  @override
  Future<void> removeConversation(Conversation conversation, bool clearMessage) async {
    _call('removeConversation', [conversation.target, conversation.conversationType.index, conversation.line, clearMessage]);
  }

  @override
  void setConversationTop(Conversation conversation, int isTop,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    _call('setConversationTop', [
      _convertConversation(conversation),
      isTop,
      js_util.allowInterop(successCallback),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  void setConversationSilent(Conversation conversation, bool isSilent,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    _call('setConversationSlient', [
      _convertConversation(conversation),
      isSilent,
      js_util.allowInterop(successCallback),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  Future<void> setConversationDraft(Conversation conversation, String draft) async {
    _call('setConversationDraft', [_convertConversation(conversation), draft]);
  }

  @override
  Future<void> setConversationTimestamp(Conversation conversation, int timestamp) async {
    _call('setConversationTimestamp', [_convertConversation(conversation), timestamp]);
  }

  @override
  Future<int> getFirstUnreadMessageId(Conversation conversation) async {
    final result = _call('getFirstUnreadMessageId', [_convertConversation(conversation)]);
    return _toInt(result) ?? 0;
  }

  @override
  Future<UnreadCount> getConversationUnreadCount(Conversation conversation) async {
    final result = _call('getConversationUnreadCount', [_convertConversation(conversation)]);
    if (result is Map) {
      return ImclientPlatform.convertProtoUnreadCount(result);
    }
    return UnreadCount();
  }

  @override
  Future<UnreadCount> getConversationsUnreadCount(List<ConversationType> types, List<int> lines) async {
    final typeIndexes = types.map((e) => e.index).toList();
    final result = _call('getUnreadCount', [typeIndexes, lines.isEmpty ? [0] : lines]);
    if (result is Map) {
      return ImclientPlatform.convertProtoUnreadCount(result);
    }
    return UnreadCount();
  }

  @override
  Future<bool> clearConversationUnreadStatus(Conversation conversation) async {
    _call('clearConversationUnreadStatus', [_convertConversation(conversation)]);
    return true;
  }

  @override
  Future<bool> clearConversationsUnreadStatus(List<ConversationType> types, List<int> lines) async {
    _call('clearAllUnreadStatus');
    return true;
  }

  @override
  Future<bool> clearConversationUnreadStatusBeforeMessage(
      Conversation conversation, int messageId) async {
    _call('clearUnreadStatusBeforeMessage', [_convertConversation(conversation), messageId]);
    return true;
  }

  @override
  Future<bool> clearMessageUnreadStatus(int messageId) async {
    _call('clearMessageUnreadStatus', [messageId]);
    return true;
  }

  @override
  Future<bool> markAsUnRead(Conversation conversation, bool sync) async {
    // Web SDK does not expose this directly.
    return false;
  }

  @override
  Future<Map<String, int>> getConversationRead(Conversation conversation) async {
    final result = _call('getConversationRead', [_convertConversation(conversation)]);
    if (result is Map<String, int>) return result;
    return {};
  }

  @override
  Future<Map<String, int>> getMessageDelivery(Conversation conversation) async {
    return {};
  }

  @override
  Future<List<Message>> getMessages(Conversation conversation, int fromIndex, int count,
      {List<int>? contentTypes, String? withUser}) async {
    final completer = Completer<List<Message>>();
    _call('getMessagesV2', [
      _convertConversation(conversation),
      fromIndex,
      false, // before
      count,
      withUser ?? '',
      js_util.allowInterop((dynamic msgs) {
        if (msgs is! List) {
          completer.complete([]);
          return;
        }
        final list = msgs.reversed
            .whereType<Map>()
            .map((e) => ImclientPlatform.convertProtoMessage(e))
            .whereType<Message>()
            .toList();
        completer.complete(list);
      }),
      js_util.allowInterop((dynamic code) {
        completer.complete([]);
      })
    ]);
    return completer.future;
  }

  @override
  Future<List<Message>> getMessagesByStatus(
      Conversation conversation, int fromIndex, int count, List<MessageStatus>? messageStatus,
      {String? withUser}) async {
    return [];
  }

  @override
  Future<List<Message>> getConversationsMessages(List<ConversationType> types, List<int> lines,
      int fromIndex, int count,
      {List<int>? contentTypes, String? withUser}) async {
    return [];
  }

  @override
  Future<List<Message>> getConversationsMessageByStatus(List<ConversationType> types,
      List<int> lines, int fromIndex, int count, List<MessageStatus> messageStatus,
      {String? withUser}) async {
    return [];
  }

  @override
  void getRemoteMessages(Conversation conversation, int beforeMessageUid, int count,
      OperationSuccessMessagesCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? contentTypes}) {
    _call('loadRemoteConversationMessages', [
      _convertConversation(conversation),
      contentTypes ?? [],
      beforeMessageUid,
      count,
      js_util.allowInterop((dynamic msgs) {
        final list = _toMessageList(msgs);
        successCallback(list);
      }),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  void getRemoteMessage(int messageUid, OperationSuccessMessageCallback successCallback,
      OperationFailureCallback errorCallback) {
    _call('loadRemoteMessage', [
      messageUid,
      js_util.allowInterop((dynamic msg) {
        final m = ImclientPlatform.convertProtoMessage(msg as Map?);
        if (m != null) successCallback(m);
      }),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  Future<Message?> getMessage(int messageId) async {
    final result = _call('getMessageById', [messageId]);
    return ImclientPlatform.convertProtoMessage(result as Map?);
  }

  @override
  Future<Message?> getMessageByUid(int messageUid) async {
    final result = _call('getMessageByUid', [messageUid]);
    return ImclientPlatform.convertProtoMessage(result as Map?);
  }

  @override
  Future<List<Message>> searchMessages(Conversation conversation, String keyword,
      bool order, int limit, int offset) async {
    final result = _call('searchMessageEx', [_convertConversation(conversation), keyword, order, limit, offset, '']);
    return _toMessageList(result);
  }

  @override
  Future<List<Message>> searchConversationsMessages(List<ConversationType> types,
      List<int> lines, String keyword, int fromIndex, int count,
      {List<int>? contentTypes}) async {
    return [];
  }

  @override
  Future<Message> sendMessage(
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

  @override
  Future<Message> sendMediaMessage(
      Conversation conversation, MessageContent content,
      {List<String>? toUsers,
      int expireDuration = 0,
      required SendMessageSuccessCallback successCallback,
      required OperationFailureCallback errorCallback,
      SendMediaMessageProgressCallback? progressCallback,
      SendMediaMessageUploadedCallback? uploadedCallback}) async {
    final requestId = _requestId++;
    _sendMessageSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    if (progressCallback != null) {
      _sendMediaMessageProgressCallbackMap[requestId] = progressCallback;
    }
    if (uploadedCallback != null) {
      _sendMediaMessageUploadedCallbackMap[requestId] = uploadedCallback;
    }

    final convMap = _convertConversation(conversation);
    final contMap = ImclientPlatform.convertMessageContent(content);

    final message = Message();
    message.conversation = conversation;
    message.content = content;
    message.direction = MessageDirection.MessageDirection_Send;
    message.status = MessageStatus.Message_Status_Sending;
    message.serverTime = DateTime.now().millisecondsSinceEpoch;

    _call('sendConversationMessage', [
      convMap,
      contMap,
      toUsers ?? [],
      js_util.allowInterop((dynamic messageId, dynamic timestamp) {
        message.messageId = _toInt(messageId) ?? 0;
        message.serverTime = _toInt(timestamp) ?? message.serverTime;
        _sendingMessages[requestId] = message;
        IMEventBus.fire(SendMessageStartEvent(message));
      }),
      js_util.allowInterop((dynamic uploaded, dynamic total) {
        final cb = _sendMediaMessageProgressCallbackMap[requestId];
        cb?.call(_toInt(uploaded) ?? 0, _toInt(total) ?? 0);
      }),
      js_util.allowInterop((dynamic messageUid, dynamic timestamp) {
        final uid = _toInt(messageUid) ?? 0;
        message.messageUid = uid;
        message.serverTime = _toInt(timestamp) ?? message.serverTime;
        message.status = MessageStatus.Message_Status_Sent;
        _sendMessageSuccessCallbackMap[requestId]?.call(uid, message.serverTime);
        _removeSendMessageCallback(requestId);
        IMEventBus.fire(SendMessageSuccessEvent(message, message.messageId, uid, message.serverTime));
      }),
      js_util.allowInterop((dynamic code) {
        message.status = MessageStatus.Message_Status_Send_Failure;
        _errorCallbackMap[requestId]?.call(_toInt(code) ?? -1);
        _removeSendMessageCallback(requestId);
        IMEventBus.fire(SendMessageFailureEvent(message, message.messageId, _toInt(code) ?? -1));
      })
    ]);

    return message;
  }

  @override
  Future<bool> sendSavedMessage(int messageId,
      {int expireDuration = 0,
      required SendMessageSuccessCallback successCallback,
      required OperationFailureCallback errorCallback}) async {
    return false;
  }

  @override
  Future<bool> sendSavedMessage2(Message message,
      {int expireDuration = 0,
      required SendMessageSuccessCallback successCallback,
      required OperationFailureCallback errorCallback}) async {
    return false;
  }

  @override
  Future<bool> cancelSendingMessage(int messageId) async {
    final result = _call('cancelSendingMessage', [messageId]);
    return result == true;
  }

  @override
  void recallMessage(int messageUid, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    _call('recallMessage', [
      messageUid,
      js_util.allowInterop(successCallback),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  void uploadMedia(String fileName, Uint8List mediaData, int mediaType,
      OperationSuccessStringCallback successCallback,
      SendMediaMessageProgressCallback progressCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void uploadMediaFile(String filePath, int mediaType,
      OperationSuccessStringCallback successCallback,
      SendMediaMessageProgressCallback progressCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void getMediaUploadUrl(String fileName, int mediaType, String contentType,
      void Function(String uploadUrl, String downloadUrl, String backupUploadUrl, int type) successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<bool> isSupportBigFilesUpload() async => false;

  @override
  Future<bool> deleteMessage(int messageId) async {
    final result = _call('deleteMessage', [messageId]);
    return result == true;
  }

  @override
  Future<bool> batchDeleteMessages(List<int> messageUids) async {
    for (final uid in messageUids) {
      _call('deleteMessageByUid', [uid]);
    }
    return true;
  }

  @override
  void deleteRemoteMessage(int messageUid, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    _call('deleteRemoteMessageByUid', [
      messageUid,
      js_util.allowInterop(successCallback),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  Future<bool> clearMessages(Conversation conversation, {int before = 0}) async {
    _call('clearMessages', [_convertConversation(conversation)]);
    return true;
  }

  @override
  Future<bool> clearMessagesKeepLatest(Conversation conversation, int keepCount) async {
    return false;
  }

  @override
  void clearRemoteConversationMessage(Conversation conversation,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<void> setMediaMessagePlayed(int messageId) async {
    _call('setMediaMessagePlayed', [messageId]);
  }

  @override
  Future<bool> setMessageLocalExtra(int messageId, String localExtra) async {
    _call('setMessageLocalExtra', [messageId, localExtra]);
    return true;
  }

  @override
  Future<Message> insertMessage(Conversation conversation, String sender,
      MessageContent content, int status, int serverTime,
      {List<String>? toUsers}) async {
    throw UnimplementedError('insertMessage not supported on web');
  }

  @override
  Future<bool> updateMessage(int messageId, MessageContent content) async {
    return false;
  }

  @override
  void updateRemoteMessageContent(int messageUid, MessageContent content, bool distribute,
      bool updateLocal, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<void> updateMessageStatus(int messageId, MessageStatus status) async {}

  @override
  Future<int> getMessageCount(Conversation conversation) async {
    return 0;
  }

  @override
  Future<UserInfo?> getUserInfo(String userId,
      {String? groupId, bool refresh = false}) async {
    final result = _call('getUserInfo', [userId, refresh, groupId ?? '']);
    return ImclientPlatform.convertProtoUserInfo(result as Map?);
  }

  @override
  Future<List<UserInfo>> getUserInfos(List<String> userIds,
      {String? groupId}) async {
    final result = _call('getUserInfos', [userIds, groupId ?? '']);
    if (result is! List) return [];
    return result
        .whereType<Map>()
        .map((e) => ImclientPlatform.convertProtoUserInfo(e))
        .whereType<UserInfo>()
        .toList();
  }

  @override
  void getUserInfoAsync(String userId, OperationSuccessUserInfoCallback successCallback,
      OperationFailureCallback errorCallback,
      {String? groupId, bool refresh = false}) {
    _call('getUserInfoEx', [
      userId,
      refresh,
      js_util.allowInterop((dynamic info) {
        final user = ImclientPlatform.convertProtoUserInfo(info as Map?);
        if (user != null) successCallback(user);
      }),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  void searchUser(String keyword, int searchType, int page,
      OperationSuccessUserInfosCallback successCallback,
      OperationFailureCallback errorCallback) {
    _call('searchUser', [
      keyword,
      searchType,
      page,
      js_util.allowInterop((dynamic users) {
        final list = _toUserInfoList(users);
        successCallback(list);
      }),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  Future<bool> isMyFriend(String userId) async {
    final result = _call('isMyFriend', [userId]);
    return result == true;
  }

  @override
  Future<List<String>> getMyFriendList({bool refresh = false}) async {
    final result = _call('getMyFriendList', [refresh]);
    return _toStringList(result);
  }

  @override
  Future<List<Friend>> getFriends(bool refresh) async {
    final result = _call('getFriendList', [refresh]);
    if (result is! List) return [];
    return result.whereType<Map>().map((e) => ImclientPlatform.convertProtoFriend(e)).toList();
  }

  @override
  Future<List<UserInfo>> searchFriends(String keyword) async {
    final result = _call('searchFriends', [keyword]);
    if (result is! List) return [];
    return result
        .whereType<Map>()
        .map((e) => ImclientPlatform.convertProtoUserInfo(e))
        .whereType<UserInfo>()
        .toList();
  }

  @override
  Future<List<FriendRequest>> getIncommingFriendRequest() async {
    final result = _call('getIncommingFriendRequest');
    return _toFriendRequestList(result);
  }

  @override
  Future<List<FriendRequest>> getOutgoingFriendRequest() async {
    final result = _call('getOutgoingFriendRequest');
    return _toFriendRequestList(result);
  }

  @override
  Future<FriendRequest?> getFriendRequest(String userId, FriendRequestDirection direction) async {
    final result = _call('getOneFriendRequest', [userId, direction.index]);
    return ImclientPlatform.convertProtoFriendRequest(result as Map?);
  }

  @override
  Future<void> loadFriendRequestFromRemote() async {
    return;
  }

  @override
  Future<int> getUnreadFriendRequestStatus() async {
    final result = _call('getUnreadFriendRequestCount');
    return _toInt(result) ?? 0;
  }

  @override
  Future<bool> clearUnreadFriendRequestStatus() async {
    _call('clearUnreadFriendRequestStatus');
    return true;
  }

  @override
  Future<bool> clearFriendRequest(int direction, beforeTime) async {
    return false;
  }

  @override
  Future<bool> deleteFriendRequest(String userId, int direction) async {
    return false;
  }

  @override
  void deleteFriend(String userId, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    _call('deleteFriend', [
      userId,
      js_util.allowInterop(successCallback),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  void sendFriendRequest(String userId, String reason,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    _call('sendFriendRequest', [
      userId,
      reason,
      js_util.allowInterop(successCallback),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  void handleFriendRequest(String userId, bool accept, String extra,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<String?> getFriendAlias(String userId) async {
    final result = _call('getFriendAlias', [userId]);
    return result?.toString();
  }

  @override
  void setFriendAlias(String friendId, String? alias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<String> getFriendExtra(String userId) async {
    final result = _call('getFriendExtra', [userId]);
    return result?.toString() ?? '';
  }

  @override
  Future<bool> isBlackListed(String userId) async {
    final result = _call('isBlackListed', [userId]);
    return result == true;
  }

  @override
  Future<List<String>> getBlackList({bool refresh = false}) async {
    final result = _call('getBlackList');
    return _toStringList(result);
  }

  @override
  void setBlackList(String userId, bool isBlackListed,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<List<GroupMember>> getGroupMembers(String groupId, {bool refresh = false}) async {
    final result = _call('getGroupMembers', [groupId, refresh]);
    if (result is! List) return [];
    return result.whereType<Map>().map((e) => ImclientPlatform.convertProtoGroupMember(e)!).toList();
  }

  @override
  Future<List<GroupMember>> getGroupMembersByCount(String groupId, int count) async {
    return [];
  }

  @override
  Future<List<GroupMember>> getGroupMembersByTypes(String groupId, GroupMemberType memberType) async {
    final result = _call('getGroupMembersByType', [groupId, memberType.index]);
    return _toGroupMemberList(result);
  }

  @override
  void getGroupMembersAsync(String groupId,
      {bool refresh = false,
      required OperationSuccessGroupMembersCallback successCallback,
      required OperationFailureCallback errorCallback}) {
    _call('getGroupMembersEx', [
      groupId,
      refresh,
      js_util.allowInterop((dynamic members) {
        successCallback(_toGroupMemberList(members));
      }),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  Future<GroupInfo?> getGroupInfo(String groupId, {bool refresh = false}) async {
    final result = _call('getGroupInfo', [groupId, refresh]);
    return await ImclientPlatform.convertProtoGroupInfo(result as Map?);
  }

  @override
  Future<List<GroupInfo>> getGroupInfos(List<String> groupIds, {bool refresh = false}) async {
    final list = <GroupInfo>[];
    for (final id in groupIds) {
      final info = await getGroupInfo(id, refresh: refresh);
      if (info != null) list.add(info);
    }
    return list;
  }

  @override
  void getGroupInfoAsync(String groupId,
      {bool refresh = false,
      required OperationSuccessGroupInfoCallback successCallback,
      required OperationFailureCallback errorCallback}) {
    _call('getGroupInfoEx', [
      groupId,
      refresh,
      js_util.allowInterop((dynamic info) {
        Future(() async {
          final group = await ImclientPlatform.convertProtoGroupInfo(info as Map?);
          if (group != null) successCallback(group);
        });
      }),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  Future<GroupMember?> getGroupMember(String groupId, String memberId) async {
    final result = _call('getGroupMember', [groupId, memberId]);
    return ImclientPlatform.convertProtoGroupMember(result as Map);
  }

  @override
  void createGroup(String? groupId, String? groupName, String? groupPortrait, int type,
      List<String> members, OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines, MessageContent? notifyContent}) {
    errorCallback(-1);
  }

  @override
  void addGroupMembers(String groupId, List<String> members,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines, MessageContent? notifyContent}) {
    errorCallback(-1);
  }

  @override
  void kickoffGroupMembers(String groupId, List<String> members,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines, MessageContent? notifyContent}) {
    errorCallback(-1);
  }

  @override
  void quitGroup(String groupId, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines, MessageContent? notifyContent}) {
    errorCallback(-1);
  }

  @override
  void quitGroupEx(String groupId, bool keepMessage,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines, MessageContent? notifyContent}) {
    errorCallback(-1);
  }

  @override
  void dismissGroup(String groupId, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines, MessageContent? notifyContent}) {
    errorCallback(-1);
  }

  @override
  void modifyGroupInfo(String groupId, ModifyGroupInfoType modifyType, String newValue,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines, MessageContent? notifyContent}) {
    errorCallback(-1);
  }

  @override
  void modifyGroupAlias(String groupId, String newAlias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines, MessageContent? notifyContent}) {
    errorCallback(-1);
  }

  @override
  void modifyGroupMemberAlias(String groupId, String memberId, String newAlias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines, MessageContent? notifyContent}) {
    errorCallback(-1);
  }

  @override
  void transferGroup(String groupId, String newOwner,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines, MessageContent? notifyContent}) {
    errorCallback(-1);
  }

  @override
  void setGroupManager(String groupId, bool isSet, List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines, MessageContent? notifyContent}) {
    errorCallback(-1);
  }

  @override
  void muteGroupMember(String groupId, bool isSet, List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines, MessageContent? notifyContent}) {
    errorCallback(-1);
  }

  @override
  void allowGroupMember(String groupId, bool isSet, List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines, MessageContent? notifyContent}) {
    errorCallback(-1);
  }

  @override
  Future<String> getGroupRemark(String groupId) async => '';

  @override
  void setGroupRemark(String groupId, String remark,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<List<String>> getFavGroups() async {
    final result = _call('getFavGroups');
    return _toStringList(result);
  }

  @override
  Future<bool> isFavGroup(String groupId) async {
    final result = _call('isFavGroup', [groupId]);
    return result == true;
  }

  @override
  void setFavGroup(String groupId, bool isFav,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<String> getUserSetting(int scope, String key) async {
    final result = _call('getUserSetting', [scope, key]);
    return result?.toString() ?? '';
  }

  @override
  Future<Map<String, String>> getUserSettings(int scope) async {
    final result = _call('getUserSettings', [scope]);
    if (result is Map<String, String>) return result;
    if (result is Map) {
      return result.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''));
    }
    return {};
  }

  @override
  void setUserSetting(int scope, String key, String value,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    _call('setUserSetting', [
      scope,
      key,
      value,
      js_util.allowInterop(successCallback),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  void modifyMyInfo(Map<ModifyMyInfoType, String> values, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<bool> isGlobalSilent() async {
    final result = _call('isGlobalSlient');
    return result == true;
  }

  @override
  void setGlobalSilent(bool isSilent, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    _call('setGlobalSlient', [
      isSilent,
      js_util.allowInterop(successCallback),
      js_util.allowInterop((dynamic code) => errorCallback(_toInt(code) ?? -1))
    ]);
  }

  @override
  Future<bool> isVoipNotificationSilent() async => false;

  @override
  void setVoipNotificationSilent(bool isSilent,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<bool> isEnableSyncDraft() async {
    final result = _call('isDisableSyncDraft');
    return result != true;
  }

  @override
  void setEnableSyncDraft(bool enable, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void getNoDisturbingTimes(OperationSuccessIntPairCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void setNoDisturbingTimes(int startMins, int endMins,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void clearNoDisturbingTimes(OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<bool> isNoDisturbing() async => false;

  @override
  Future<bool> isHiddenNotificationDetail() async {
    final result = _call('isHiddenNotificationDetail');
    return result == true;
  }

  @override
  void setHiddenNotificationDetail(bool isHidden,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<bool> isHiddenGroupMemberName(String groupId) async {
    final result = _call('isHiddenGroupMemberName', [groupId]);
    return result == true;
  }

  @override
  void setHiddenGroupMemberName(String groupId, bool isHidden,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void getMyGroups(OperationSuccessStringListCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void getCommonGroups(String userId, OperationSuccessStringListCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void setUserEnableReceipt(bool isEnable, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<List<String>> getFavUsers() async {
    final result = _call('getFavUsers');
    return _toStringList(result);
  }

  @override
  Future<bool> isFavUser(String userId) async {
    final result = _call('isFavUser', [userId]);
    return result == true;
  }

  @override
  void setFavUser(String userId, bool isFav, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void joinChatroom(String chatroomId, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void quitChatroom(String chatroomId, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void getChatroomInfo(String chatroomId, int updateDt,
      OperationSuccessChatroomInfoCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void getChatroomMemberInfo(String chatroomId,
      OperationSuccessChatroomMemberInfoCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<String> getJoinedChatroomId() async => '';

  @override
  void createChannel(String channelName, String channelPortrait, String desc, String extra,
      OperationSuccessChannelInfoCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<ChannelInfo?> getChannelInfo(String channelId, {bool refresh = false}) async {
    final result = _call('getChannelInfo', [channelId, refresh]);
    return ImclientPlatform.convertProtoChannelInfo(result as Map?);
  }

  @override
  void modifyChannelInfo(String channelId, ModifyChannelInfoType modifyType, String newValue,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void searchChannel(String keyword, OperationSuccessChannelInfosCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<bool> isListenedChannel(String channelId) async {
    final result = _call('isListenedChannel', [channelId]);
    return result == true;
  }

  @override
  void listenChannel(String channelId, bool isListen,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<List<String>> getMyChannels() async {
    final result = _call('getMyChannels');
    return _toStringList(result);
  }

  @override
  void getRemoteListenedChannels(OperationSuccessStringListCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void destroyChannel(String channelId, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<List<PCOnlineInfo>> getOnlineInfos() async {
    return [];
  }

  @override
  void kickoffPCClient(String clientId, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<bool> isMuteNotificationWhenPcOnline() async => false;

  @override
  Future<bool> setDefaultSilentWhenPcOnline(bool defaultSilent) async {
    return true;
  }

  @override
  void muteNotificationWhenPcOnline(bool isMute,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<UserOnlineState?> getUserOnlineState(String userId) async {
    return _useOnlineCacheMap[userId];
  }

  @override
  Future<CustomState> getMyCustomState() async => CustomState(0);

  @override
  void setMyCustomState(int customState, String? customText,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void watchOnlineState(ConversationType conversationType, List<String> targets, int watchDuration,
      OperationSuccessWatchUserOnlineCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void unwatchOnlineState(ConversationType conversationType, List<String> targets,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<bool> isEnableUserOnlineState() async {
    final result = _call('isUserOnlineStateEnabled');
    return result == true;
  }

  @override
  void sendConferenceRequest(int sessionId, String roomId, String request,
      bool advanced, String data, OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void getConversationFiles(int beforeMessageUid, FileRecordOrder order, int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback,
      {Conversation? conversation, String? fromUser}) {
    errorCallback(-1);
  }

  @override
  void getMyFiles(int beforeMessageUid, FileRecordOrder order, int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void deleteFileRecord(int messageUid, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void searchFiles(String keyword, int beforeMessageUid, FileRecordOrder order, int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback,
      {Conversation? conversation, String? fromUser}) {
    errorCallback(-1);
  }

  @override
  void searchMyFiles(String keyword, int beforeMessageUid, FileRecordOrder order, int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void getAuthorizedMediaUrl(String mediaPath, int messageUid, int mediaType,
      OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void getAuthCode(String applicationId, int type, String host,
      OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  void configApplication(String applicationId, int type, int timestamp, String nonce,
      String signature, OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    errorCallback(-1);
  }

  @override
  Future<Uint8List> getWavData(String amrPath) async => Uint8List(0);

  @override
  Future<bool> beginTransaction() async => false;

  @override
  Future<bool> commitTransaction() async => false;

  @override
  Future<bool> rollbackTransaction() async => false;

  @override
  Future<bool> isCommercialServer() async => false;

  @override
  Future<bool> isReceiptEnabled() async {
    final result = _call('isReceiptEnabled');
    return result == true;
  }

  @override
  Future<bool> isUserEnableReceipt() async {
    final result = _call('isUserReceiptEnabled');
    return result == true;
  }

  @override
  Future<bool> isGroupReceiptEnabled() async {
    final result = _call('isGroupReceiptEnabled');
    return result == true;
  }

  @override
  Future<bool> isGlobalDisableSyncDraft() async {
    final result = _call('isGlobalDisableSyncDraft');
    return result == true;
  }

  // Helper methods

  Map<dynamic, dynamic> _convertConversation(Conversation conversation) {
    return {
      'type': conversation.conversationType.index,
      'target': conversation.target,
      'line': conversation.line,
    };
  }

  List<Message> _toMessageList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => ImclientPlatform.convertProtoMessage(e))
        .whereType<Message>()
        .toList();
  }

  List<UserInfo> _toUserInfoList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => ImclientPlatform.convertProtoUserInfo(e))
        .whereType<UserInfo>()
        .toList();
  }

  List<GroupMember> _toGroupMemberList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => ImclientPlatform.convertProtoGroupMember(e))
        .whereType<GroupMember>()
        .toList();
  }

  List<FriendRequest> _toFriendRequestList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => ImclientPlatform.convertProtoFriendRequest(e))
        .whereType<FriendRequest>()
        .toList();
  }

  List<String> _toStringList(dynamic value) {
    if (value is! List) return [];
    return value.map((e) => e.toString()).toList();
  }

  void _removeSendMessageCallback(int requestId) {
    _sendMessageSuccessCallbackMap.remove(requestId);
    _errorCallbackMap.remove(requestId);
    _sendMediaMessageProgressCallbackMap.remove(requestId);
    _sendMediaMessageUploadedCallbackMap.remove(requestId);
    _sendingMessages.remove(requestId);
  }
}
