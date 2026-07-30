import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart' as mc;
import 'package:imclient/model/conversation.dart';

import 'ipc_codec.dart';
import 'proxy_completer.dart';
import 'shared_imclient_channel.dart';
import 'window_event_channel.dart';

/// 主窗口侧把 payload map 重建成 [mc.MessageContent] 的工厂。
///
/// [sendMessage] / [updateMessage] 需要 MessageContent 对象,而主窗口不理解
/// 各业务的消息类型,只做原样透传。具体实现由知道消息类型的一方在 install 时
/// 注入(当前是通话的 `RawVoipMessageContent.fromMap`),避免 multi_window
/// 公共层反向依赖 call_window。
typedef RawContentDecoder = mc.MessageContent Function(
    Map<String, dynamic> payloadMap);

/// 主窗口侧**唯一**的 IM 代理:所有子窗口的 Imclient 调用都由它代执行,
/// 事件名统一为 `im.<method>`(见 [kSharedImEventPrefix])。
///
/// 与子窗口侧的 [SharedImclientChannel] 一一对应,两者共同构成"一套 proxy +
/// 一套 channel,所有子窗口共用"的结构。此前是每个窗口一份 proxy + 一份
/// channel,同一个 `getUserInfo` 有四份实现,已造成三次静默故障
/// (见 [SharedImclientChannel] 类注释)。
///
/// ## 两条硬约束
///
/// **1. 参数按 imclient 的原始 args 键名读取。** 子窗口侧透传不整形,这里也
/// 不发明第三套键名——契约就是 imclient 自己的参数定义。历史上三次故障里有
/// 两次是键名/字段在中间层被写错。
///
/// **2. 回调式接口必须经 [ProxyCompleter] 绕回类型化 API,不能透传 requestId。**
/// `ImclientPlatform._requestId` 是 `static int _requestId = 0`,每个窗口
/// isolate 各自从 0 开始;回调存在本 isolate 的 `_operationSuccessCallbackMap`
/// 里。把子窗口的 requestId 原样喂给原生,回调会带着这个 id 回到**主 isolate**
/// 的表里查:要么查不到(回调静默丢失),要么撞上主窗口自己在飞的同号请求,
/// 触发错的 callback。绕回类型化 API 后由主 isolate 重新分配 requestId,
/// 回调闭包词法捕获子窗口的 requestId,闭包本身就是那张映射表。
///
/// 桌面端还有一层原因:requestId 会被当作指针地址传给 C 层
/// (`Pointer<Void>.fromAddress(requestId)`),且负值被 FFI 通道保留作内部等待,
/// 所以它不是一个可以随意编码窗口信息的字段。
///
/// ## 仍然禁止转发的方法
///
/// [_blockedMethods] 里是进程/连接级方法。子窗口若能调 `disconnect`
/// (clearSession) 就等于把用户登出,`connect` / `initProto` 会破坏主窗口的
/// 唯一 IM 连接。这些不在 [SharedImclientChannel] 的方法表里,这里再挡一道。
class MainImclientProxy {
  static final MainImclientProxy instance = MainImclientProxy._internal();

  MainImclientProxy._internal();

  static const String _tag = 'MainImclientProxy';

  bool _installed = false;
  RawContentDecoder? _rawContentDecoder;

  /// 进程/连接级方法:永远不代子窗口执行。
  static const Set<String> _blockedMethods = {
    'connect',
    'disconnect',
    'initProto',
    'useSM4',
    'setLiteMode',
    'setProxyInfo',
    'setBackupAddress',
    'setBackupAddressStrategy',
    'setDeviceToken',
    'setVoipDeviceToken',
    'setProtoUserAgent',
    'addHttpHeader',
    'startLog',
    'stopLog',
  };

  /// 安装代理。应在主窗口 [Imclient.init] 完成后、其它窗口代理之前调用。
  ///
  /// [rawContentDecoder] 供 sendMessage / updateMessage 重建 MessageContent;
  /// 未注入时这两个方法返回失败而不是抛异常。
  void install({RawContentDecoder? rawContentDecoder}) {
    if (_installed) return;
    _installed = true;
    _rawContentDecoder = rawContentDecoder;

    final channel = WindowEventChannel();
    channel.listen();
    _registerHandlers(channel);
  }

  /// 共享方法的完整事件名。子窗口侧 [SharedImclientChannel] 生成同样的名字。
  static String event(String method) => '$kSharedImEventPrefix.$method';

  void _register(WindowEventChannel channel, String method,
      Future<dynamic> Function(dynamic) handler) {
    assert(!_blockedMethods.contains(method),
        '$method 是进程/连接级方法,不得代子窗口执行');
    channel.register(event(method), handler);
  }

  void _registerHandlers(WindowEventChannel channel) {
    // ---------------------------------------------------------- 无副作用查询
    _register(channel, 'getUserInfo', _handleGetUserInfo);
    _register(channel, 'getUserInfos', _handleGetUserInfos);
    _register(channel, 'getGroupMembers', _handleGetGroupMembers);
    _register(channel, 'currentUserId', (_) async => Imclient.currentUserId);
    _register(channel, 'clientId', (_) async => await Imclient.clientId);
    _register(channel, 'connectionStatus',
        (_) async => await Imclient.connectionStatus);
    _register(channel, 'isLogined', (_) async => await Imclient.isLogined);
    _register(
        channel, 'serverDeltaTime', (_) async => await Imclient.serverDeltaTime);

    // ---------------------------------------------------------- 消息读取
    _register(channel, 'getMessages', _handleGetMessages);
    _register(channel, 'searchMessages', _handleSearchMessages);
    _register(
        channel, 'getMessagesByTimestamp', _handleGetMessagesByTimestamp);
    _register(channel, 'getMessageCountByDay', _handleGetMessageCountByDay);
    _register(channel, 'getMessageByUid', _handleGetMessageByUid);
    _register(channel, 'getConversationsMessageByStatus',
        _handleGetConversationsMessageByStatus);

    // ---------------------------------------------------------- 会话未读
    _register(channel, 'getConversationsUnreadCount',
        _handleGetConversationsUnreadCount);
    _register(channel, 'clearConversationsUnreadStatus',
        _handleClearConversationsUnreadStatus);

    // ---------------------------------------------------------- 消息写入
    _register(channel, 'sendMessage', _handleSendMessage);
    _register(channel, 'updateMessage', _handleUpdateMessage);

    // ---------------------------------------------------------- 聊天室
    _register(channel, 'joinChatroom', _handleJoinChatroom);
    _register(channel, 'quitChatroom', _handleQuitChatroom);

    // ---------------------------------------------------------- 回调式接口
    _register(
        channel, 'sendConferenceRequest', _handleSendConferenceRequest);
    _register(channel, 'sendMomentsRequest', _handleSendMomentsRequest);
    _register(channel, 'uploadMedia', _handleUploadMedia);
    _register(channel, 'uploadMediaFile', _handleUploadMediaFile);
    _register(channel, 'getConversationFiles', _handleGetConversationFiles);
    _register(channel, 'searchFiles', _handleSearchFiles);
    _register(channel, 'getAuthorizedMediaUrl', _handleGetAuthorizedMediaUrl);
    _register(channel, 'deleteFileRecord', _handleDeleteFileRecord);
    _register(channel, 'getAuthCode', _handleGetAuthCode);
    _register(channel, 'configApplication', _handleConfigApplication);
  }

  // ------------------------------------------------------------------ 查询

  Future<dynamic> _handleGetUserInfo(dynamic args) async {
    final userInfo = await Imclient.getUserInfo(
      args['userId'] as String? ?? '',
      groupId: args['groupId'] as String?,
      refresh: args['refresh'] as bool? ?? false,
    );
    return userInfo != null ? IpcCodec.encodeUserInfo(userInfo) : null;
  }

  Future<dynamic> _handleGetUserInfos(dynamic args) async {
    final userInfos = await Imclient.getUserInfos(
      (args['userIds'] as List?)?.cast<String>() ?? <String>[],
      groupId: args['groupId'] as String?,
    );
    return userInfos.map(IpcCodec.encodeUserInfo).toList();
  }

  Future<dynamic> _handleGetGroupMembers(dynamic args) async {
    final members = await Imclient.getGroupMembers(
      args['groupId'] as String? ?? '',
      refresh: args['refresh'] as bool? ?? false,
    );
    return members.map(IpcCodec.encodeGroupMember).toList();
  }

  // ------------------------------------------------------------------ 消息读取

  Future<dynamic> _handleGetMessages(dynamic args) async {
    final messages = await Imclient.getMessages(
      _conversation(args),
      args['fromIndex'] as int? ?? 0,
      args['count'] as int? ?? 0,
      contentTypes: (args['contentTypes'] as List?)?.cast<int>(),
      withUser: args['withUser'] as String?,
    );
    return messages.map(IpcCodec.encodeMessage).toList();
  }

  Future<dynamic> _handleSearchMessages(dynamic args) async {
    final messages = await Imclient.searchMessages(
      _conversation(args),
      args['keyword'] as String? ?? '',
      args['order'] as bool? ?? true,
      args['limit'] as int? ?? 0,
      args['offset'] as int? ?? 0,
    );
    return messages.map(IpcCodec.encodeMessage).toList();
  }

  Future<dynamic> _handleGetMessagesByTimestamp(dynamic args) async {
    final messages = await Imclient.getMessagesByTimestamp(
      _conversation(args),
      args['timestamp'] as int? ?? 0,
      args['count'] as int? ?? 0,
      contentTypes: (args['contentTypes'] as List?)?.cast<int>(),
      withUser: args['withUser'] as String?,
    );
    return messages.map(IpcCodec.encodeMessage).toList();
  }

  Future<dynamic> _handleGetMessageCountByDay(dynamic args) async {
    return await Imclient.getMessageCountByDay(
      _conversation(args),
      args['startTime'] as int? ?? 0,
      args['endTime'] as int? ?? 0,
      contentTypes: (args['contentTypes'] as List?)?.cast<int>(),
    );
  }

  Future<dynamic> _handleGetMessageByUid(dynamic args) async {
    final message =
        await Imclient.getMessageByUid(args['messageUid'] as int? ?? 0);
    return message != null ? IpcCodec.encodeMessage(message) : null;
  }

  Future<dynamic> _handleGetConversationsMessageByStatus(dynamic args) async {
    final messages = await Imclient.getConversationsMessageByStatus(
      _conversationTypes(args),
      _lines(args),
      args['fromIndex'] as int? ?? 0,
      args['count'] as int? ?? 100,
      (args['messageStatus'] as List? ?? const [])
          .map((e) => MessageStatus.values[e as int])
          .toList(),
      withUser: args['withUser'] as String?,
    );
    return messages.map(IpcCodec.encodeMessage).toList();
  }

  // ------------------------------------------------------------------ 会话未读

  Future<dynamic> _handleGetConversationsUnreadCount(dynamic args) async {
    final unread = await Imclient.getConversationsUnreadCount(
        _conversationTypes(args), _lines(args));
    return IpcCodec.encodeUnreadCount(unread);
  }

  Future<dynamic> _handleClearConversationsUnreadStatus(dynamic args) async {
    await Imclient.clearConversationsUnreadStatus(
        _conversationTypes(args), _lines(args));
    return null;
  }

  // ------------------------------------------------------------------ 消息写入

  /// 返回值是主窗口本地入库的 message(与移动端 sendMessage 返回语义一致);
  /// 成功/失败在服务器 ack 之后才知道,经 `im.onSendMessageResult` 回传给
  /// **发起的那个**窗口(窗口 id 由子窗口在 args 里带上)。
  ///
  /// 回调是闭包,词法捕获了子窗口的 requestId 与 windowId,因此不需要跨窗口的
  /// requestId 映射表。
  Future<dynamic> _handleSendMessage(dynamic args) async {
    final requestId = args['requestId'] as int?;
    final windowId = SharedImclientChannel.windowIdOf(args);
    final conversation = _conversation(args);
    final contentJson = args['content'] as Map<String, dynamic>?;
    final toUsers = (args['toUsers'] as List?)?.cast<String>();
    final expireDuration = args['expireDuration'] as int? ?? 0;

    final content = _decodeContent(contentJson);
    if (content == null) {
      _emitSendMessageResult(windowId, requestId, -1);
      return null;
    }

    try {
      final message = await Imclient.sendMessage(
        conversation,
        content,
        toUsers: toUsers,
        expireDuration: expireDuration,
        successCallback: (messageUid, timestamp) => _emitSendMessageResult(
            windowId, requestId, 0,
            messageUid: messageUid, timestamp: timestamp),
        errorCallback: (errorCode) =>
            _emitSendMessageResult(windowId, requestId, errorCode),
      );
      return IpcCodec.encodeMessage(message);
    } catch (e) {
      debugPrint('$_tag sendMessage failed: $e');
      _emitSendMessageResult(windowId, requestId, -1);
      // 即使主窗口发送失败/异常,也回一个带原 payload 的失败消息,让子窗口能
      // 正常走完回调,避免 contentType 缺失导致的二次崩溃。
      return _buildFailedMessage(conversation, contentJson, toUsers);
    }
  }

  Future<dynamic> _handleUpdateMessage(dynamic args) async {
    final content = _decodeContent(args['content'] as Map<String, dynamic>?);
    if (content == null) return null;
    await Imclient.updateMessage(args['messageId'] as int? ?? 0, content);
    return null;
  }

  void _emitSendMessageResult(int? windowId, int? requestId, int errorCode,
      {int messageUid = 0, int timestamp = 0}) {
    if (windowId == null || requestId == null) {
      debugPrint('$_tag sendMessage result dropped: '
          'windowId=$windowId requestId=$requestId');
      return;
    }
    // 窗口可能在 ack 到达前已关闭,invoke 失败按 MissingPluginException 静默处理。
    WindowEventChannel.invoke(
        windowId, SharedImclientChannel.sendMessageResultEvent, {
      'requestId': requestId,
      'errorCode': errorCode,
      'messageUid': messageUid,
      'timestamp': timestamp,
    });
  }

  mc.MessageContent? _decodeContent(Map<String, dynamic>? payloadMap) {
    if (payloadMap == null) return null;
    final decoder = _rawContentDecoder;
    if (decoder == null) {
      debugPrint('$_tag no rawContentDecoder installed, '
          'sendMessage/updateMessage unavailable');
      return null;
    }
    return decoder(payloadMap);
  }

  /// 发送异常时的兜底消息,只为让子窗口的回调链走完。
  Map<String, dynamic> _buildFailedMessage(Conversation conversation,
      Map<String, dynamic>? contentJson, List<String>? toUsers) {
    return {
      'messageId': 0,
      'messageUid': 0,
      'conversation': IpcCodec.encodeConversation(conversation),
      'fromUser': Imclient.currentUserId,
      'toUsers': toUsers,
      'direction': 0,
      'status': MessageStatus.Message_Status_Send_Failure.index,
      'serverTime': 0,
      'localExtra': null,
      'content': contentJson,
    };
  }

  // ------------------------------------------------------------------ 聊天室

  Future<dynamic> _handleJoinChatroom(dynamic args) async {
    final completer = Completer<dynamic>();
    Imclient.joinChatroom(
      args['chatroomId'] as String? ?? '',
      () => completer.complete(null),
      (errorCode) => completer.complete({'errorCode': errorCode}),
    );
    return completer.future;
  }

  Future<dynamic> _handleQuitChatroom(dynamic args) async {
    final completer = Completer<dynamic>();
    Imclient.quitChatroom(
      args['chatroomId'] as String? ?? '',
      () => completer.complete(null),
      (errorCode) => completer.complete({'errorCode': errorCode}),
    );
    return completer.future;
  }

  // ------------------------------------------------------------------ 回调式接口

  Future<dynamic> _handleSendConferenceRequest(dynamic args) async {
    return ProxyCompleter.stringResult((onSuccess, onFailure) =>
        Imclient.sendConferenceRequest(
          args['sessionId'] as int? ?? 0,
          args['roomId'] as String? ?? '',
          args['request'] as String? ?? '',
          args['advanced'] as bool? ?? false,
          args['data'] as String? ?? '',
          onSuccess,
          onFailure,
        ));
  }

  Future<dynamic> _handleSendMomentsRequest(dynamic args) async {
    return ProxyCompleter.stringResult((onSuccess, onFailure) =>
        Imclient.sendMomentsRequest(
          args['path'] as String? ?? '',
          args['data'] as String? ?? '',
          onSuccess,
          onFailure,
        ));
  }

  Future<dynamic> _handleUploadMedia(dynamic args) async {
    final mediaData = args['mediaData'];
    if (mediaData is! Uint8List) {
      debugPrint('$_tag uploadMedia rejected: '
          'mediaData is ${mediaData.runtimeType}, expected Uint8List');
      return {'errorCode': -1, 'result': null};
    }
    return ProxyCompleter.stringResult((onSuccess, onFailure) =>
        Imclient.uploadMedia(
          args['fileName'] as String? ?? '',
          mediaData,
          mc.MediaType.values[args['mediaType'] as int? ?? 0],
          onSuccess,
          (current, total) {},
          onFailure,
        ));
  }

  Future<dynamic> _handleUploadMediaFile(dynamic args) async {
    return ProxyCompleter.stringResult((onSuccess, onFailure) =>
        Imclient.uploadMediaFile(
          args['filePath'] as String? ?? '',
          mc.MediaType.values[args['mediaType'] as int? ?? 0],
          onSuccess,
          (current, total) {},
          onFailure,
        ));
  }

  Future<dynamic> _handleGetConversationFiles(dynamic args) async {
    return ProxyCompleter.filesResult(
      (onSuccess, onFailure) => Imclient.getConversationFiles(
        args['beforeMessageUid'] as int? ?? 0,
        FileRecordOrder.values[args['order'] as int? ?? 0],
        args['count'] as int? ?? 20,
        onSuccess,
        onFailure,
        conversation: args['conversation'] != null ? _conversation(args) : null,
        fromUser: args['userId'] as String?,
      ),
      IpcCodec.encodeFileRecord,
    );
  }

  Future<dynamic> _handleSearchFiles(dynamic args) async {
    return ProxyCompleter.filesResult(
      (onSuccess, onFailure) => Imclient.searchFiles(
        args['keyword'] as String? ?? '',
        args['beforeMessageUid'] as int? ?? 0,
        FileRecordOrder.values[args['order'] as int? ?? 0],
        args['count'] as int? ?? 20,
        onSuccess,
        onFailure,
        conversation: args['conversation'] != null ? _conversation(args) : null,
        fromUser: args['userId'] as String?,
      ),
      IpcCodec.encodeFileRecord,
    );
  }

  Future<dynamic> _handleGetAuthorizedMediaUrl(dynamic args) async {
    return ProxyCompleter.stringResult((onSuccess, onFailure) =>
        Imclient.getAuthorizedMediaUrl(
          args['mediaPath'] as String? ?? '',
          args['messageUid'] as int? ?? 0,
          args['mediaType'] as int? ?? 0,
          onSuccess,
          onFailure,
        ));
  }

  Future<dynamic> _handleDeleteFileRecord(dynamic args) async {
    return ProxyCompleter.voidResult((onSuccess, onFailure) =>
        Imclient.deleteFileRecord(
            args['messageUid'] as int? ?? 0, onSuccess, onFailure));
  }

  /// 键名对齐 imclient 侧原始 args:`applicationId` / `type`
  /// (**不是** `appId` / `appType`——历史上在中间层写错过)。
  Future<dynamic> _handleGetAuthCode(dynamic args) async {
    return ProxyCompleter.stringResult((onSuccess, onFailure) =>
        Imclient.getAuthCode(
          args['applicationId'] as String? ?? '',
          args['type'] as int? ?? 0,
          args['host'] as String? ?? '',
          onSuccess,
          onFailure,
        ));
  }

  Future<dynamic> _handleConfigApplication(dynamic args) async {
    return ProxyCompleter.voidResult((onSuccess, onFailure) =>
        Imclient.configApplication(
          args['applicationId'] as String? ?? '',
          args['type'] as int? ?? 0,
          args['timestamp'] as int? ?? 0,
          args['nonce'] as String? ?? '',
          args['signature'] as String? ?? '',
          onSuccess,
          onFailure,
        ));
  }

  // ------------------------------------------------------------------ 参数解析

  Conversation _conversation(dynamic args) => IpcCodec.decodeConversation(
      args['conversation'] as Map<dynamic, dynamic>? ?? const {});

  List<ConversationType> _conversationTypes(dynamic args) =>
      (args['types'] as List? ?? const [])
          .map((e) => ConversationType.values[e as int])
          .toList();

  List<int> _lines(dynamic args) =>
      (args['lines'] as List? ?? const []).cast<int>();
}
