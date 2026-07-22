import 'package:flutter/services.dart';
import 'package:imclient/imclient_method_channel.dart';

import '../multi_window/window_event_channel.dart';
import 'search_window_ipc.dart';

/// 会话内搜索窗口中替换 [ImclientPlatform.instance._channel] 的代理实现。
///
/// 搜索窗口不连接 IM，所有 IM 调用都通过 [WindowEventChannel] 转发到主窗口
/// 执行，与朋友圈窗口的 [MomentWindowImclientChannel] 同构。
///
/// 返回值式接口（getMessages/searchMessages 等）直接回传主窗口的执行结果；
/// 回调式接口（文件记录、授权 URL 等）沿用 requestId + 回调映射模式：
/// 主窗口执行后经 IPC 返回 {errorCode, ...}，这里按原生回调事件的既有语义
/// 走 [ImclientPlatform] 的 dispatch 方法触发回调并清理。
class SearchWindowImclientChannel implements ImclientChannel {
  static const String _tag = 'SearchWindowImclientChannel';

  final int _mainWindowId = 0;

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    switch (method) {
      case 'registerMessage':
        // 消息类型注册只作用于 Dart 层解码，原生侧已在主窗口完成注册。
        return null;
      case 'getMessages':
        return await _invokeSimple(SearchMainEvents.getMessages, arguments)
            as T?;
      case 'searchMessages':
        return await _invokeSimple(SearchMainEvents.searchMessages, arguments)
            as T?;
      case 'getMessagesByTimestamp':
        return await _invokeSimple(
            SearchMainEvents.getMessagesByTimestamp, arguments) as T?;
      case 'getMessageCountByDay':
        return await _invokeSimple(
            SearchMainEvents.getMessageCountByDay, arguments) as T?;
      case 'getUserInfo':
        return await _invokeSimple(SearchMainEvents.getUserInfo, arguments)
            as T?;
      case 'getConversationFiles':
        return await _filesRequest(
            SearchMainEvents.getConversationFiles, arguments) as T?;
      case 'searchFiles':
        return await _filesRequest(SearchMainEvents.searchFiles, arguments)
            as T?;
      case 'getAuthorizedMediaUrl':
        return await _stringRequest(
            SearchMainEvents.getAuthorizedMediaUrl, arguments) as T?;
      case 'deleteFileRecord':
        return await _voidRequest(SearchMainEvents.deleteFileRecord, arguments)
            as T?;
      default:
        throw UnsupportedError(
          '$_tag method $method is not supported in search window',
        );
    }
  }

  @override
  void setMethodCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    // 搜索窗口不执行 ImclientPlatform.init，没有原生事件经此 handler 分发。
  }

  Future<dynamic> _invokeSimple(String event, dynamic args) async {
    return await WindowEventChannel.invoke(_mainWindowId, event, args);
  }

  /// 文件记录列表类接口（getConversationFiles/searchFiles）：
  /// 主窗口返回 {errorCode, files}，这里按 onFilesResult 的语义触发回调。
  Future<dynamic> _filesRequest(String event, dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final requestId = map['requestId'] as int;
    final result = await WindowEventChannel.invoke(_mainWindowId, event, args);
    final errorCode = (result is Map) ? (result['errorCode'] as int? ?? -1) : -1;
    final files = (result is Map) ? result['files'] as List<dynamic>? : null;
    ImclientPlatform.dispatchOperationResult(requestId, errorCode, files: files);
    return null;
  }

  /// 字符串结果类接口（getAuthorizedMediaUrl）：
  /// 主窗口返回 {errorCode, result}，按 onOperationStringSuccess 的语义触发回调。
  Future<dynamic> _stringRequest(String event, dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final requestId = map['requestId'] as int;
    final result = await WindowEventChannel.invoke(_mainWindowId, event, args);
    final errorCode = (result is Map) ? (result['errorCode'] as int? ?? -1) : -1;
    final raw = (result is Map) ? result['result'] : null;
    ImclientPlatform.dispatchConferenceRequestResult(
        requestId, errorCode, raw is String ? raw : '');
    return null;
  }

  /// 无参成功回调类接口（deleteFileRecord）：
  /// 主窗口返回 {errorCode}，按 onOperationVoidSuccess 的语义触发回调。
  Future<dynamic> _voidRequest(String event, dynamic args) async {
    final map = args as Map<dynamic, dynamic>;
    final requestId = map['requestId'] as int;
    final result = await WindowEventChannel.invoke(_mainWindowId, event, args);
    final errorCode = (result is Map) ? (result['errorCode'] as int? ?? -1) : -1;
    ImclientPlatform.dispatchOperationResult(requestId, errorCode);
    return null;
  }
}
