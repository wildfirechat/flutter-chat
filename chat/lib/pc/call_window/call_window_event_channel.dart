import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';

/// 主窗口与 Call 窗口之间的通信通道封装。
///
/// 基于 [DesktopMultiWindow.invokeMethod] 实现：
/// - 主窗口调用 Call 窗口：invokeMethod(callWindowId, method, args)
/// - Call 窗口调用主窗口：invokeMethod(0, method, args)
///
/// 所有跨窗口消息都序列化为 JSON 字符串，避免 isolate 之间传递复杂对象。
class CallWindowEventChannel {
  static const String _tag = 'CallWindowEventChannel';

  final int _windowId;
  final Map<String, Future<dynamic> Function(dynamic args)> _handlers = {};

  CallWindowEventChannel(this._windowId);

  /// 注册消息处理器。
  void register(String method, Future<dynamic> Function(dynamic args) handler) {
    _handlers[method] = handler;
  }

  /// 取消注册消息处理器。
  void unregister(String method) {
    _handlers.remove(method);
  }

  /// 开始监听跨窗口消息。
  void listen() {
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      final handler = _handlers[call.method];
      if (handler == null) {
        print('$_tag no handler for ${call.method} from window $fromWindowId');
        return null;
      }
      try {
        final args = _decode(call.arguments);
        return await handler(args);
      } catch (e, s) {
        print('$_tag handle ${call.method} error: $e\n$s');
        rethrow;
      }
    });
  }

  /// 向目标窗口发送消息。
  static Future<T?> invoke<T>(int targetWindowId, String method, dynamic args) async {
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        targetWindowId,
        method,
        _encode(args),
      );
      if (result == null) return null;
      return _decode(result) as T?;
    } on MissingPluginException {
      // 目标窗口引擎尚未完成插件注册，属于临时状态，返回 null 让上层重试或兜底。
      print('$_tag invoke $method to window $targetWindowId: plugin not ready');
      return null;
    } on PlatformException catch (e) {
      print('$_tag invoke $method to window $targetWindowId error: ${e.message}');
      rethrow;
    }
  }

  /// method channel 已支持 Map/List/基本类型跨 isolate 传递，
  /// 这里只做类型归一化（把 Map<Object?, Object?>/List<Object?> 转成
  /// Map<String, dynamic>/List<dynamic>），不再二次 JSON 编解码，
  /// 避免把本来就是 String 的返回值（如会议请求 result）误解析成 Map。
  static dynamic _encode(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _encode(v)));
    }
    if (value is List) {
      return value.map(_encode).toList();
    }
    return value;
  }

  static dynamic _decode(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _decode(v)));
    }
    if (value is List) {
      return value.map(_decode).toList();
    }
    return value;
  }
}

/// 主窗口 → Call 窗口 的事件名。
class CallWindowEvents {
  /// 转发收到的 IM 消息。
  static const String message = 'voip.message';

  /// 转发会议事件。
  static const String conferenceEvent = 'voip.conferenceEvent';

  /// 转发 IM 连接状态变化。
  static const String connectionStatus = 'voip.connectionStatus';

  /// 主动发起单人/多人通话。
  static const String startCall = 'voip.startCall';

  /// 主动创建会议。
  static const String startConference = 'voip.startConference';

  /// 主动加入会议。
  static const String joinConference = 'voip.joinConference';
}

/// Call 窗口 → 主窗口 的事件名。
class MainWindowEvents {
  /// Imclient.sendMessage / sendConversationMessage。
  static const String sendMessage = 'imclient.sendMessage';

  /// Imclient.sendConferenceRequest。
  static const String sendConferenceRequest = 'imclient.sendConferenceRequest';

  /// Imclient.updateMessageContent。
  static const String updateMessageContent = 'imclient.updateMessageContent';

  /// Imclient.getMessageByUid。
  static const String getMessageByUid = 'imclient.getMessageByUid';

  /// Imclient.getUserInfo。
  static const String getUserInfo = 'imclient.getUserInfo';

  /// Imclient.getUserInfos。
  static const String getUserInfos = 'imclient.getUserInfos';

  /// Imclient.getGroupMemberIds。
  static const String getGroupMemberIds = 'imclient.getGroupMemberIds';

  /// Imclient.getGroupMembers。
  static const String getGroupMembers = 'imclient.getGroupMembers';

  /// Imclient.joinChatroom。
  static const String joinChatroom = 'imclient.joinChatroom';

  /// Imclient.quitChatroom。
  static const String quitChatroom = 'imclient.quitChatroom';

  /// Imclient.currentUserId。
  static const String currentUserId = 'imclient.currentUserId';

  /// Imclient.clientId。
  static const String clientId = 'imclient.clientId';

  /// Imclient.connectionStatus。
  static const String connectionStatus = 'imclient.connectionStatus';

  /// Imclient.isLogined。
  static const String isLogined = 'imclient.isLogined';

  /// 通话窗口状态变化（可选）。
  static const String voipStatusChanged = 'voip.statusChanged';

  /// 通话窗口关闭。
  static const String windowClosed = 'voip.windowClosed';
}
