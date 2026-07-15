import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:imclient/imclient_method_channel.dart';
import 'package:imclient/src/imclient_channel.dart';

import 'call_window_event_channel.dart';

/// Call 窗口中替换 [ImclientPlatform.instance._channel] 的代理实现。
///
/// 所有 IM 调用都通过 [CallWindowEventChannel] 转发到主窗口执行，
/// 主窗口执行真实 [Imclient] 后再把结果返回。
///
/// 对于 [sendMessage] 这类带异步回调的调用，回调仍注册在
/// [ImclientPlatform] 的既有 requestId 映射里;主窗口拿到服务器
/// ack/失败后经 `voip.sendMessageResult` 事件回传,由
/// [handleSendMessageResult] 走 [ImclientPlatform.dispatchSendMessageResult]
/// 统一触发回调并清理,与移动端 onSendMessageSuccess/Failure 语义一致。
class CallWindowImclientChannel implements ImclientChannel {
  static const String _tag = 'CallWindowImclientChannel';

  final int _mainWindowId = 0;

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    switch (method) {
      case 'registerMessage':
        // Call 窗口的音视频类型注册只作用于 Dart 层解码，不通过 IM channel
        // 传给原生。原生侧已在主窗口完成注册。
        return null;
      case 'sendMessage':
        return await _sendMessage(arguments) as T?;
      case 'sendConferenceRequest':
        return await _sendConferenceRequest(arguments) as T?;
      case 'updateMessage':
        return await _updateMessage(arguments) as T?;
      case 'getMessageByUid':
        return await _getMessageByUid(arguments) as T?;
      case 'getUserInfo':
        return await _getUserInfo(arguments) as T?;
      case 'getUserInfos':
        return await _getUserInfos(arguments) as T?;
      case 'getGroupMembers':
        return await _getGroupMembers(arguments) as T?;
      case 'joinChatroom':
        return await _joinChatroom(arguments) as T?;
      case 'quitChatroom':
        return await _quitChatroom(arguments) as T?;
      case 'currentUserId':
        return await _invokeSimple(MainWindowEvents.currentUserId, arguments) as T?;
      case 'clientId':
        return await _invokeSimple(MainWindowEvents.clientId, arguments) as T?;
      case 'connectionStatus':
        return await _invokeSimple(MainWindowEvents.connectionStatus, arguments) as T?;
      case 'isLogined':
        return await _invokeSimple(MainWindowEvents.isLogined, arguments) as T?;
      case 'serverDeltaTime':
        return await _invokeSimple(MainWindowEvents.serverDeltaTime, arguments) as T?;
      default:
        throw UnsupportedError(
          '$_tag method $method is not supported in call window',
        );
    }
  }

  @override
  void setMethodCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    // Call 窗口不执行 ImclientPlatform.init,没有原生事件会经此 handler 分发;
    // 主窗口转发来的事件由 CallWindowApp 直接 fire 到本 isolate 的 IMEventBus。
  }

  /// 主窗口经 `voip.sendMessageResult` 回传的发送结果。
  void handleSendMessageResult(dynamic args) {
    final map = args as Map<dynamic, dynamic>;
    final requestId = map['requestId'] as int?;
    if (requestId == null) return;
    ImclientPlatform.dispatchSendMessageResult(
      requestId,
      map['errorCode'] as int? ?? 0,
      messageUid: map['messageUid'] as int? ?? 0,
      timestamp: map['timestamp'] as int? ?? 0,
    );
  }

  Future<dynamic> _sendMessage(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final conversationMap = map['conversation'] as Map<dynamic, dynamic>;
    final contentMap = map['content'] as Map<dynamic, dynamic>;
    final toUsers = (map['toUsers'] as List?)?.cast<String>();
    final expireDuration = map['expireDuration'] as int? ?? 0;
    final requestId = map['requestId'] as int;

    // 返回值只是主窗口本地入库的 message(与移动端 sendMessage 的返回语义一致);
    // 成功/失败回调由主窗口在服务器 ack 后经 sendMessageResult 事件异步回传。
    return await CallWindowEventChannel.invoke(
      _mainWindowId,
      MainWindowEvents.sendMessage,
      {
        'requestId': requestId,
        'conversation': conversationMap,
        'content': contentMap,
        'toUsers': toUsers,
        'expireDuration': expireDuration,
      },
    );
  }

  Future<dynamic> _sendConferenceRequest(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final sessionId = map['sessionId'] as int;
    final roomId = map['roomId'] as String;
    final request = map['request'] as String;
    final advanced = map['advanced'] as bool? ?? false;
    final data = map['data'] as String? ?? '';
    final requestId = map['requestId'] as int;

    final result = await CallWindowEventChannel.invoke(
      _mainWindowId,
      MainWindowEvents.sendConferenceRequest,
      {
        'requestId': requestId,
        'sessionId': sessionId,
        'roomId': roomId,
        'request': request,
        'advanced': advanced,
        'data': data,
      },
    );

    final errorCode = (result is Map) ? (result['errorCode'] as int? ?? 0) : 0;
    final raw = (result is Map) ? result['result'] : null;
    final String payload;
    if (raw == null) {
      payload = '';
    } else if (raw is String) {
      payload = raw;
    } else {
      payload = jsonEncode(raw);
    }
    ImclientPlatform.dispatchConferenceRequestResult(requestId, errorCode, payload);
    return result;
  }

  Future<dynamic> _updateMessage(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final messageId = map['messageId'] as int;
    final contentMap = map['content'] as Map<dynamic, dynamic>;

    await CallWindowEventChannel.invoke(
      _mainWindowId,
      MainWindowEvents.updateMessageContent,
      {
        'messageId': messageId,
        'content': contentMap,
      },
    );
    return null;
  }

  Future<dynamic> _getMessageByUid(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final messageUid = map['messageUid'] as int;
    final result = await CallWindowEventChannel.invoke(
      _mainWindowId,
      MainWindowEvents.getMessageByUid,
      {'messageUid': messageUid},
    );
    return result;
  }

  Future<dynamic> _getUserInfo(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final userId = map['userId'] as String;
    final refresh = map['refresh'] as bool? ?? false;
    final result = await CallWindowEventChannel.invoke(
      _mainWindowId,
      MainWindowEvents.getUserInfo,
      {'userId': userId, 'refresh': refresh},
    );
    return result;
  }

  Future<dynamic> _getUserInfos(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final userIds = (map['userIds'] as List).cast<String>();
    final groupId = map['groupId'] as String?;
    final result = await CallWindowEventChannel.invoke(
      _mainWindowId,
      MainWindowEvents.getUserInfos,
      {'userIds': userIds, 'groupId': groupId},
    );
    return result;
  }

  Future<dynamic> _getGroupMembers(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final groupId = map['groupId'] as String;
    final refresh = map['refresh'] as bool? ?? false;
    final result = await CallWindowEventChannel.invoke(
      _mainWindowId,
      MainWindowEvents.getGroupMembers,
      {'groupId': groupId, 'refresh': refresh},
    );
    return result;
  }

  Future<dynamic> _joinChatroom(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final chatroomId = map['chatroomId'] as String;
    await CallWindowEventChannel.invoke(
      _mainWindowId,
      MainWindowEvents.joinChatroom,
      {'chatroomId': chatroomId},
    );
    return null;
  }

  Future<dynamic> _quitChatroom(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final chatroomId = map['chatroomId'] as String;
    await CallWindowEventChannel.invoke(
      _mainWindowId,
      MainWindowEvents.quitChatroom,
      {'chatroomId': chatroomId},
    );
    return null;
  }

  Future<dynamic> _invokeSimple(String event, dynamic args) async {
    return await CallWindowEventChannel.invoke(_mainWindowId, event, args);
  }
}
