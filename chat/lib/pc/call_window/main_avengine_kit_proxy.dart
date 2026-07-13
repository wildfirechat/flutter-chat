import 'dart:async';
import 'dart:convert';

import 'package:event_bus/event_bus.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart' as mc;
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/message_payload.dart';
import 'package:imclient/model/user_info.dart';

import 'call_window_event_channel.dart';
import 'call_window_manager.dart';
import 'model_codec.dart';
import 'raw_voip_message_content.dart';

/// 主窗口中的音视频通话代理。
///
/// 对应 PC 端 Electron 的 `AvEngineKitProxy`，负责：
/// 1. 监听 IM 消息/会议事件/连接状态变化。
/// 2. 创建/管理 Call 窗口。
/// 3. 把 IM 事件转发到 Call 窗口。
/// 4. 代 Call 窗口执行 IM 操作。
///
/// 注意：主窗口不持有任何 avenginekit 业务逻辑，只通过 [RawVoipMessageContent]
/// 对 VOIP 消息做“原样透传”。
class MainAvEngineKitProxy {
  static const String _tag = 'MainAvEngineKitProxy';
  static final MainAvEngineKitProxy instance = MainAvEngineKitProxy._internal();

  MainAvEngineKitProxy._internal();

  final EventBus _eventBus = Imclient.IMEventBus;
  StreamSubscription? _receiveMessageSubscription;
  StreamSubscription? _conferenceEventSubscription;
  StreamSubscription? _connectionStatusSubscription;

  /// 当前活跃的 Call 窗口信息。
  int? _callWindowId;
  bool _callWindowReady = false;

  /// 待转发的事件队列（窗口未 ready 时缓存）。
  final List<_QueuedEvent> _eventQueue = [];

  /// 是否已经安装代理。
  bool _installed = false;

  /// 安装代理。
  ///
  /// 应该在主窗口 [Imclient.init] 完成后调用，确保 VOIP 占位类型注册在
  /// IM SDK ready 之后。
  void install() {
    if (_installed) return;
    _installed = true;

    _registerVoipMessageTypes();

    _receiveMessageSubscription = _eventBus.on<ReceiveMessagesEvent>().listen((event) {
      _onReceiveMessages(event.messages, event.hasMore);
    });
    _conferenceEventSubscription = _eventBus.on<ConferenceEvent>().listen((event) {
      _onConferenceEvent(event.event);
    });
    _connectionStatusSubscription = _eventBus.on<ConnectionStatusChangedEvent>().listen((event) {
      _onConnectionStatusChanged(event.connectionStatus);
    });

    // 监听 Call 窗口发回的事件。
    final channel = CallWindowEventChannel(0);
    channel.listen();
    _registerMainWindowHandlers(channel);
  }

  void _registerVoipMessageTypes() {
    for (final entry in _voipTypes) {
      Imclient.registerMessageContent(
        mc.MessageContentMeta(
          entry.type,
          entry.flag,
          () => RawVoipMessageContent(entry.type, entry.flag),
        ),
      );
    }
  }

  void uninstall() {
    _receiveMessageSubscription?.cancel();
    _conferenceEventSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _receiveMessageSubscription = null;
    _conferenceEventSubscription = null;
    _connectionStatusSubscription = null;
    _installed = false;
  }

  /// 主动发起单人/多人通话。
  Future<void> startCall(
    Conversation conversation,
    List<String> participants,
    bool audioOnly, {
    String callExtra = '',
  }) async {
    if (_callWindowId != null) {
      print('$_tag call already in progress');
      return;
    }

    final selfUserId = Imclient.currentUserId;
    final userInfos = await _getParticipantUserInfos(conversation, participants);
    final groupMembers = conversation.conversationType == ConversationType.Group
        ? await Imclient.getGroupMembers(conversation.target)
        : <GroupMember>[];

    final args = <String, dynamic>{
      'conversation': _conversationToJson(conversation),
      'selfUserId': selfUserId,
      'participants': participants,
      'audioOnly': audioOnly,
      'callExtra': callExtra,
      'participantUserInfos': userInfos.map((e) => ModelCodec.encodeUserInfo(e)).toList(),
      'groupMemberUserInfos': groupMembers.map((e) => ModelCodec.encodeGroupMember(e)).toList(),
    };

    await _ensureCallWindow(
      conversation: conversation,
      isConference: false,
      initialEvent: CallWindowEvents.startCall,
      initialArgs: args,
    );
  }

  /// 主动创建会议。
  Future<void> startConference({
    required String callId,
    required bool audioOnly,
    String? pin,
    required String host,
    required String title,
    String desc = '',
    bool audience = false,
    bool advance = false,
    bool record = false,
    String extra = '',
    String callExtra = '',
    bool muteAudio = false,
    bool muteVideo = false,
  }) async {
    if (_callWindowId != null) {
      print('$_tag call already in progress');
      return;
    }

    final completer = Completer<void>();
    Imclient.joinChatroom(
      callId,
      () => completer.complete(),
      (errorCode) => completer.complete(),
    );
    await completer.future;

    final args = <String, dynamic>{
      'callId': callId,
      'audioOnly': audioOnly,
      'pin': pin,
      'host': host,
      'title': title,
      'desc': desc,
      'audience': audience,
      'advance': advance,
      'record': record,
      'extra': extra,
      'callExtra': callExtra,
      'muteAudio': muteAudio,
      'muteVideo': muteVideo,
    };

    await _ensureCallWindow(
      conversation: null,
      isConference: true,
      initialEvent: CallWindowEvents.startConference,
      initialArgs: args,
    );
  }

  /// 主动加入会议。
  Future<void> joinConference({
    required String callId,
    required bool audioOnly,
    String? pin,
    required String host,
    required String title,
    String desc = '',
    bool audience = false,
    bool advance = false,
    String extra = '',
    String callExtra = '',
    bool muteAudio = false,
    bool muteVideo = false,
  }) async {
    if (_callWindowId != null) {
      print('$_tag call already in progress');
      return;
    }

    final completer = Completer<void>();
    Imclient.joinChatroom(
      callId,
      () => completer.complete(),
      (errorCode) => completer.complete(),
    );
    await completer.future;

    final args = <String, dynamic>{
      'callId': callId,
      'audioOnly': audioOnly,
      'pin': pin,
      'host': host,
      'title': title,
      'desc': desc,
      'audience': audience,
      'advance': advance,
      'extra': extra,
      'callExtra': callExtra,
      'muteAudio': muteAudio,
      'muteVideo': muteVideo,
    };

    await _ensureCallWindow(
      conversation: null,
      isConference: true,
      initialEvent: CallWindowEvents.joinConference,
      initialArgs: args,
    );
  }

  /// 收到 IM 消息。
  Future<void> _onReceiveMessages(List<Message> messages, bool hasMore) async {
    if (hasMore) return;
    for (final msg in messages) {
      final type = msg.content.meta.type;
      if (!_isVoipMessageType(type)) continue;

      // 来电/邀请类消息需要先创建 Call 窗口。
      if (_callWindowId == null &&
          (type == mc.VOIP_CONTENT_TYPE_START ||
              type == mc.VOIP_CONTENT_TYPE_ADD_PARTICIPANT ||
              type == mc.VOIP_CONTENT_CONFERENCE_INVITE)) {
        await _ensureCallWindowFromIncomingMessage(msg);
      }

      _emitToCallWindow(CallWindowEvents.message, _messageToJson(msg));
    }
  }

  Future<void> _ensureCallWindowFromIncomingMessage(Message msg) async {
    final int type = msg.content.meta.type;
    final bool isConference = type == mc.VOIP_CONTENT_CONFERENCE_INVITE;
    Conversation? conversation = msg.conversation;
    if (isConference) conversation = null;

    await _ensureCallWindow(
      conversation: conversation,
      isConference: isConference,
      initialEvent: CallWindowEvents.message,
      initialArgs: _messageToJson(msg),
    );
  }

  /// 收到会议事件。
  void _onConferenceEvent(String event) {
    _emitToCallWindow(CallWindowEvents.conferenceEvent, event);
  }

  /// IM 连接状态变化。
  void _onConnectionStatusChanged(int status) {
    _emitToCallWindow(CallWindowEvents.connectionStatus, status);
  }

  /// 确保 Call 窗口存在并发送初始事件。
  Future<void> _ensureCallWindow({
    Conversation? conversation,
    required bool isConference,
    required String initialEvent,
    required Map<String, dynamic> initialArgs,
  }) async {
    print('$_tag _ensureCallWindow type=${_resolveWindowType(conversation, isConference)}');
    final windowType = _resolveWindowType(conversation, isConference);
    final windowId = await CallWindowManager.instance.createCallWindow(
      type: windowType,
      onReady: () {
        print('$_tag call window ready');
        _callWindowReady = true;
        _flushEventQueue();
        _emitToCallWindow(initialEvent, initialArgs);
      },
      onClose: () {
        print('$_tag call window closed');
        _onCallWindowClosed();
      },
    );
    _callWindowId = windowId;
    print('$_tag call window created id=$windowId');
  }

  String _resolveWindowType(Conversation? conversation, bool isConference) {
    if (isConference) return 'conference';
    if (conversation?.conversationType == ConversationType.Single) return 'single';
    return 'multi';
  }

  /// 转发事件到 Call 窗口，窗口未 ready 时入队。
  void _emitToCallWindow(String event, dynamic args) {
    if (_callWindowReady && _callWindowId != null) {
      CallWindowEventChannel.invoke(_callWindowId!, event, args);
    } else {
      _eventQueue.add(_QueuedEvent(event, args));
    }
  }

  void _flushEventQueue() {
    if (_callWindowId == null) return;
    while (_eventQueue.isNotEmpty) {
      final item = _eventQueue.removeAt(0);
      CallWindowEventChannel.invoke(_callWindowId!, item.event, item.args);
    }
  }

  void _onCallWindowClosed() {
    _callWindowId = null;
    _callWindowReady = false;
    _eventQueue.clear();
  }

  /// 注册 Call 窗口会调用的主窗口 IM 代理方法。
  void _registerMainWindowHandlers(CallWindowEventChannel channel) {
    channel.register(MainWindowEvents.sendMessage, _handleSendMessage);
    channel.register(MainWindowEvents.sendConferenceRequest, _handleSendConferenceRequest);
    channel.register(MainWindowEvents.updateMessageContent, _handleUpdateMessageContent);
    channel.register(MainWindowEvents.getMessageByUid, _handleGetMessageByUid);
    channel.register(MainWindowEvents.getUserInfo, _handleGetUserInfo);
    channel.register(MainWindowEvents.getUserInfos, _handleGetUserInfos);
    channel.register(MainWindowEvents.getGroupMembers, _handleGetGroupMembers);
    channel.register(MainWindowEvents.joinChatroom, _handleJoinChatroom);
    channel.register(MainWindowEvents.quitChatroom, _handleQuitChatroom);
    channel.register(MainWindowEvents.currentUserId, (_) async => Imclient.currentUserId);
    channel.register(MainWindowEvents.clientId, (_) async => await Imclient.clientId);
    channel.register(MainWindowEvents.connectionStatus, (_) async => await Imclient.connectionStatus);
    channel.register(MainWindowEvents.isLogined, (_) async => await Imclient.isLogined);
    channel.register(MainWindowEvents.voipStatusChanged, _handleVoipStatusChanged);
    channel.register(MainWindowEvents.windowClosed, _handleWindowClosed);
  }

  Future<dynamic> _handleVoipStatusChanged(dynamic args) async {
    final status = args['status'] as String?;
    final windowId = args['windowId'] as int?;
    if (status == 'ready' && windowId != null) {
      await CallWindowManager.instance.onCallWindowReady(windowId);
    }
    return null;
  }

  Future<dynamic> _handleSendMessage(dynamic args) async {
    final conversation = _conversationFromJson(args['conversation'] as Map<String, dynamic>);
    final contentJson = args['content'] as Map<String, dynamic>;
    final content = RawVoipMessageContent.fromMap(contentJson);
    final toUsers = (args['toUsers'] as List?)?.cast<String>();
    final expireDuration = args['expireDuration'] as int? ?? 0;

    try {
      final message = await Imclient.sendMessage(
        conversation,
        content,
        toUsers: toUsers,
        expireDuration: expireDuration,
        successCallback: (messageUid, timestamp) {},
        errorCallback: (errorCode) {},
      );
      return _messageToJson(message);
    } catch (e) {
      print('$_tag sendMessage failed: $e');
      // 即使主窗口发送失败/异常，也返回一个带原 payload 的失败消息，
      // 让 Call 窗口侧能正常走完回调，避免 contentType 缺失导致的二次崩溃。
      return _buildFailedMessage(conversation, contentJson, toUsers);
    }
  }

  Future<dynamic> _handleSendConferenceRequest(dynamic args) async {
    final sessionId = args['sessionId'] as int;
    final roomId = args['roomId'] as String;
    final request = args['request'] as String;
    final advance = args['advance'] as bool? ?? false;
    final data = args['data'] as String? ?? '';

    final completer = Completer<dynamic>();
    Imclient.sendConferenceRequest(
      sessionId,
      roomId,
      request,
      advance,
      data,
      (result) {
        completer.complete({'errorCode': 0, 'result': result});
      },
      (errorCode) {
        completer.complete({'errorCode': errorCode, 'result': null});
      },
    );
    return completer.future;
  }

  Future<dynamic> _handleUpdateMessageContent(dynamic args) async {
    final messageId = args['messageId'] as int;
    final contentJson = args['content'] as Map<String, dynamic>;
    final content = RawVoipMessageContent.fromMap(contentJson);
    await Imclient.updateMessage(messageId, content);
    return null;
  }

  Future<dynamic> _handleGetMessageByUid(dynamic args) async {
    final messageUid = args['messageUid'] as int;
    final message = await Imclient.getMessageByUid(messageUid);
    return message != null ? _messageToJson(message) : null;
  }

  Future<dynamic> _handleGetUserInfo(dynamic args) async {
    final userId = args['userId'] as String;
    final refresh = args['refresh'] as bool? ?? false;
    final userInfo = await Imclient.getUserInfo(userId, refresh: refresh);
    return userInfo != null ? ModelCodec.encodeUserInfo(userInfo) : null;
  }

  Future<dynamic> _handleGetUserInfos(dynamic args) async {
    final userIds = (args['userIds'] as List).cast<String>();
    final groupId = args['groupId'] as String?;
    final userInfos = await Imclient.getUserInfos(userIds, groupId: groupId);
    return userInfos.map((e) => ModelCodec.encodeUserInfo(e)).toList();
  }

  Future<dynamic> _handleGetGroupMembers(dynamic args) async {
    final groupId = args['groupId'] as String;
    final refresh = args['refresh'] as bool? ?? false;
    final members = await Imclient.getGroupMembers(groupId, refresh: refresh);
    return members.map((e) => ModelCodec.encodeGroupMember(e)).toList();
  }

  Future<dynamic> _handleJoinChatroom(dynamic args) async {
    final chatroomId = args['chatroomId'] as String;
    final completer = Completer<dynamic>();
    Imclient.joinChatroom(
      chatroomId,
      () => completer.complete(null),
      (errorCode) => completer.complete({'errorCode': errorCode}),
    );
    return completer.future;
  }

  Future<dynamic> _handleQuitChatroom(dynamic args) async {
    final chatroomId = args['chatroomId'] as String;
    final completer = Completer<dynamic>();
    Imclient.quitChatroom(
      chatroomId,
      () => completer.complete(null),
      (errorCode) => completer.complete({'errorCode': errorCode}),
    );
    return completer.future;
  }

  Future<dynamic> _handleWindowClosed(dynamic args) async {
    final windowId = args['windowId'] as int?;
    if (windowId != null) {
      await CallWindowManager.instance.onCallWindowClosed(windowId);
    }
    return null;
  }

  bool _isVoipMessageType(int type) {
    return type == mc.VOIP_CONTENT_TYPE_START ||
        type == mc.VOIP_CONTENT_TYPE_END ||
        type == mc.VOIP_CONTENT_TYPE_ACCEPT ||
        type == mc.VOIP_CONTENT_TYPE_ACCEPT_T ||
        type == mc.VOIP_CONTENT_TYPE_SIGNAL ||
        type == mc.VOIP_CONTENT_TYPE_MODIFY ||
        type == mc.VOIP_CONTENT_TYPE_ADD_PARTICIPANT ||
        type == mc.VOIP_CONTENT_MUTE_VIDEO ||
        type == mc.VOIP_CONTENT_CONFERENCE_CHANGE_MODE ||
        type == mc.VOIP_CONTENT_CONFERENCE_KICKOFF_MEMBER ||
        type == mc.VOIP_CONTENT_CONFERENCE_COMMAND ||
        type == mc.VOIP_CONTENT_MULTI_CALL_ONGOING ||
        type == mc.VOIP_CONTENT_JOIN_CALL_REQUEST;
  }

  Future<List<UserInfo>> _getParticipantUserInfos(
      Conversation conversation, List<String> participants) async {
    final allUserIds = [Imclient.currentUserId, ...participants];
    final userInfos = await Imclient.getUserInfos(
      allUserIds,
      groupId: conversation.conversationType == ConversationType.Group
          ? conversation.target
          : null,
    );
    return userInfos;
  }

  Map<String, dynamic> _conversationToJson(Conversation conversation) {
    return {
      'conversationType': conversation.conversationType.index,
      'target': conversation.target,
      'line': conversation.line,
    };
  }

  Conversation _conversationFromJson(Map<String, dynamic> json) {
    // 兼容 IM channel 的 proto map（key 为 type）和本地编码（key 为 conversationType）。
    final typeIndex = json['conversationType'] as int? ?? json['type'] as int;
    return Conversation(
      conversationType: ConversationType.values[typeIndex],
      target: json['target'] as String,
      line: json['line'] as int? ?? 0,
    );
  }

  Map<String, dynamic> _messageToJson(Message message) {
    final payload = message.content.encode();
    return {
      'messageId': message.messageId,
      'messageUid': message.messageUid,
      'conversation': _conversationToJson(message.conversation),
      'fromUser': message.fromUser,
      'toUsers': message.toUsers,
      'direction': message.direction.index,
      'status': message.status.index,
      'serverTime': message.serverTime,
      'localExtra': message.localExtra,
      'content': _payloadToJson(payload),
    };
  }

  Map<String, dynamic> _payloadToJson(MessagePayload payload) {
    return {
      'contentType': payload.contentType,
      'searchableContent': payload.searchableContent,
      'pushContent': payload.pushContent,
      'pushData': payload.pushData,
      'content': payload.content,
      'binaryContent': payload.binaryContent != null ? base64Encode(payload.binaryContent!) : null,
      'localContent': payload.localContent,
      'mentionedType': payload.mentionedType,
      'mentionedTargets': payload.mentionedTargets,
      'mediaType': payload.mediaType.index,
      'remoteMediaUrl': payload.remoteMediaUrl,
      'localMediaPath': payload.localMediaPath,
      'extra': payload.extra,
    };
  }

  Map<String, dynamic> _buildFailedMessage(
    Conversation conversation,
    Map<String, dynamic> contentJson,
    List<String>? toUsers,
  ) {
    final payload = RawVoipMessageContent.fromMap(contentJson).encode();
    return {
      'messageId': 0,
      'messageUid': null,
      'conversation': _conversationToJson(conversation),
      'fromUser': Imclient.currentUserId,
      'toUsers': toUsers,
      'direction': MessageDirection.MessageDirection_Send.index,
      'status': MessageStatus.Message_Status_Send_Failure.index,
      'serverTime': DateTime.now().millisecondsSinceEpoch,
      'localExtra': null,
      'content': _payloadToJson(payload),
    };
  }

  /// 所有需要主窗口注册的 VOIP 类型及其对应 flag。
  static final List<_VoipType> _voipTypes = [
    const _VoipType(mc.VOIP_CONTENT_TYPE_START, mc.MessageFlag.PERSIST_AND_COUNT),
    const _VoipType(mc.VOIP_CONTENT_TYPE_END, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(mc.VOIP_CONTENT_TYPE_ACCEPT, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(mc.VOIP_CONTENT_TYPE_ACCEPT_T, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(mc.VOIP_CONTENT_TYPE_SIGNAL, mc.MessageFlag.TRANSPARENT),
    const _VoipType(mc.VOIP_CONTENT_TYPE_MODIFY, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(mc.VOIP_CONTENT_TYPE_ADD_PARTICIPANT, mc.MessageFlag.PERSIST),
    const _VoipType(mc.VOIP_CONTENT_MUTE_VIDEO, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(mc.VOIP_CONTENT_CONFERENCE_INVITE, mc.MessageFlag.PERSIST),
    const _VoipType(mc.VOIP_CONTENT_CONFERENCE_CHANGE_MODE, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(mc.VOIP_CONTENT_CONFERENCE_KICKOFF_MEMBER, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(mc.VOIP_CONTENT_CONFERENCE_COMMAND, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(mc.VOIP_CONTENT_MULTI_CALL_ONGOING, mc.MessageFlag.NOT_PERSIST),
    const _VoipType(mc.VOIP_CONTENT_JOIN_CALL_REQUEST, mc.MessageFlag.NOT_PERSIST),
  ];
}

class _VoipType {
  final int type;
  final mc.MessageFlag flag;
  const _VoipType(this.type, this.flag);
}

class _QueuedEvent {
  final String event;
  final dynamic args;
  _QueuedEvent(this.event, this.args);
}
