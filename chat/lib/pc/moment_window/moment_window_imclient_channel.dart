import 'package:flutter/services.dart';
import 'package:imclient/imclient_method_channel.dart';
import 'package:imclient/src/imclient_channel.dart';

import '../multi_window/window_event_channel.dart';
import 'moment_ipc.dart';

/// 朋友圈窗口中替换 [ImclientPlatform.instance._channel] 的代理实现。
///
/// 朋友圈窗口不连接 IM，所有 IM 调用都通过 [WindowEventChannel] 转发到主窗口
/// 执行，与 Call 窗口的 [CallWindowImclientChannel] 同构。
class MomentWindowImclientChannel implements ImclientChannel {
  static const String _tag = 'MomentWindowImclientChannel';

  final int _mainWindowId = 0;

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    switch (method) {
      case 'registerMessage':
        // 朋友圈消息类型注册只作用于 Dart 层解码，原生侧已在主窗口完成注册。
        return null;
      case 'sendMomentsRequest':
        return await _sendMomentsRequest(arguments) as T?;
      case 'getUserInfo':
        return await _invokeSimple(MomentMainEvents.getUserInfo, arguments) as T?;
      case 'getUserInfos':
        return await _invokeSimple(MomentMainEvents.getUserInfos, arguments) as T?;
      case 'getConversationsMessageByStatus':
        return await _invokeSimple(
            MomentMainEvents.getConversationsMessageByStatus, arguments) as T?;
      case 'getConversationsUnreadCount':
        return await _invokeSimple(
            MomentMainEvents.getConversationsUnreadCount, arguments) as T?;
      case 'clearConversationsUnreadStatus':
        return await _invokeSimple(
            MomentMainEvents.clearConversationsUnreadStatus, arguments) as T?;
      case 'uploadMedia':
        return await _uploadMedia(arguments) as T?;
      case 'uploadMediaFile':
        return await _uploadMediaFile(arguments) as T?;
      case 'serverDeltaTime':
        return await _invokeSimple(MomentMainEvents.serverDeltaTime, arguments) as T?;
      default:
        throw UnsupportedError(
          '$_tag method $method is not supported in moment window',
        );
    }
  }

  @override
  void setMethodCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    // 朋友圈窗口不执行 ImclientPlatform.init，没有原生事件经此 handler 分发；
    // 主窗口转发来的事件由 MomentWindowApp 直接处理。
  }

  Future<dynamic> _invokeSimple(String event, dynamic args) async {
    return await WindowEventChannel.invoke(_mainWindowId, event, args);
  }

  /// sendMomentsRequest 使用 requestId + 回调映射模式：
  /// 主窗口执行后返回 {errorCode, result}，这里按
  /// onSendMomentsRequestSuccess/Failure 的既有语义触发回调并清理。
  Future<dynamic> _sendMomentsRequest(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final requestId = map['requestId'] as int;
    final result = await WindowEventChannel.invoke(
      _mainWindowId,
      MomentMainEvents.sendMomentsRequest,
      {
        'requestId': requestId,
        'path': map['path'],
        'data': map['data'],
      },
    );
    final errorCode =
        (result is Map) ? (result['errorCode'] as int? ?? -1) : -1;
    final raw = (result is Map) ? result['result'] : null;
    ImclientPlatform.dispatchConferenceRequestResult(
        requestId, errorCode, raw is String ? raw : '');
    return null;
  }

  /// uploadMedia 同样走 requestId + 回调映射，只回传最终 remoteUrl，忽略进度。
  Future<dynamic> _uploadMedia(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final requestId = map['requestId'] as int;
    final result = await WindowEventChannel.invoke(
      _mainWindowId,
      MomentMainEvents.uploadMedia,
      {
        'requestId': requestId,
        'fileName': map['fileName'],
        'mediaData': map['mediaData'],
        'mediaType': map['mediaType'],
      },
    );
    _dispatchUploadResult(requestId, result);
    return null;
  }

  Future<dynamic> _uploadMediaFile(dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final requestId = map['requestId'] as int;
    final result = await WindowEventChannel.invoke(
      _mainWindowId,
      MomentMainEvents.uploadMediaFile,
      {
        'requestId': requestId,
        'filePath': map['filePath'],
        'mediaType': map['mediaType'],
      },
    );
    _dispatchUploadResult(requestId, result);
    return null;
  }

  void _dispatchUploadResult(int requestId, dynamic result) {
    final errorCode =
        (result is Map) ? (result['errorCode'] as int? ?? -1) : -1;
    final raw = (result is Map) ? result['result'] : null;
    ImclientPlatform.dispatchConferenceRequestResult(
        requestId, errorCode, raw is String ? raw : '');
  }
}
