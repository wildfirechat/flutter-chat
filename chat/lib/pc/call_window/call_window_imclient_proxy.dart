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
/// 对于 [sendMessage] / [sendConferenceRequest] 这类带异步回调的调用，
/// 本代理会在 Call 窗口侧保存 requestId 到 callback 的映射，等主窗口
/// 返回结果后再主动触发回调。
class CallWindowImclientChannel implements ImclientChannel {
  static const String _tag = 'CallWindowImclientChannel';

  final int _mainWindowId = 0;
  Future<dynamic> Function(MethodCall call)? _methodCallHandler;

  int _requestId = 0;
  final Map<int, Function> _successCallbacks = {};
  final Map<int, Function> _errorCallbacks = {};

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
    _methodCallHandler = handler;
  }

  /// 主窗口把 IM 事件转发过来时，还原成 [MethodCall] 喂给 handler。
  void dispatchMethodCall(String method, dynamic args) {
    if (_methodCallHandler == null) return;
    final call = MethodCall(method, args);
    _methodCallHandler!(call);
  }

  Future<dynamic> _sendMessage(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final conversationMap = map['conversation'] as Map<dynamic, dynamic>;
    final contentMap = map['content'] as Map<dynamic, dynamic>;
    final toUsers = (map['toUsers'] as List?)?.cast<String>();
    final expireDuration = map['expireDuration'] as int? ?? 0;
    final requestId = map['requestId'] as int;

    final result = await CallWindowEventChannel.invoke(
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

    final errorCode = (result is Map) ? (result['errorCode'] as int? ?? 0) : 0;
    if (errorCode == 0) {
      final successCb = _sendMessageSuccessCallback(requestId);
      if (successCb != null) {
        final messageUid = (result is Map) ? result['messageUid'] as int? ?? 0 : 0;
        final serverTime = (result is Map) ? result['serverTime'] as int? ?? 0 : 0;
        successCb(messageUid, serverTime);
      }
    } else {
      final errorCb = _sendMessageErrorCallback(requestId);
      errorCb?.call(errorCode);
    }

    return result;
  }

  Future<dynamic> _sendConferenceRequest(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final sessionId = map['sessionId'] as int;
    final roomId = map['roomId'] as String;
    final request = map['request'] as String;
    final advance = map['advanced'] as bool? ?? false;
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
        'advance': advance,
        'data': data,
      },
    );

    final errorCode = (result is Map) ? (result['errorCode'] as int? ?? 0) : 0;
    if (errorCode == 0) {
      final successCb = _conferenceSuccessCallback(requestId);
      if (successCb != null) {
        final raw = (result is Map) ? result['result'] : null;
        final String? payload;
        if (raw == null) {
          payload = null;
        } else if (raw is String) {
          payload = raw;
        } else {
          payload = jsonEncode(raw);
        }
        successCb(payload);
      }
    } else {
      final errorCb = _conferenceErrorCallback(requestId);
      errorCb?.call(errorCode);
    }

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

  Function? _sendMessageSuccessCallback(int requestId) {
    return ImclientPlatform.sendMessageSuccessCallbackMap[requestId];
  }

  Function? _sendMessageErrorCallback(int requestId) {
    return ImclientPlatform.errorCallbackMap[requestId];
  }

  Function? _conferenceSuccessCallback(int requestId) {
    return ImclientPlatform.operationSuccessCallbackMap[requestId];
  }

  Function? _conferenceErrorCallback(int requestId) {
    return _sendMessageErrorCallback(requestId);
  }
}
