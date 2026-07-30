import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:imclient/imclient_method_channel.dart';

import 'window_event_channel.dart';

/// PC 子窗口侧通用的 IM 代理通道:替换 [ImclientPlatform] 的
/// [ImclientChannel],把 IM 调用经 [WindowEventChannel] 转发到主窗口执行。
///
/// 子窗口(call/moment/search/wfWebView)不连接 IM,各自保留一个本类的子类,
/// 在构造时用 [forwardSimple]/[forwardShared]/[forward]/[forwardWithRequestId]
/// 声明方法表:
///
/// - [forwardSimple]:按原 args 转发到 `$eventPrefix.$method`,回传主窗口结果;
/// - [forwardShared]:转发到各窗口共用的 `im.$method`(主窗口侧由
///   MainImclientProxy 一处实现),用于无副作用的读接口;
/// - [forward]:先用 reshapeArgs 整形参数再转发,回传主窗口结果;
/// - [forwardWithRequestId]:回调式接口。主窗口同步返回
///   `{errorCode, result}`(或 files 等其它字段)后,交给 dispatch 闭包走
///   [ImclientPlatform] 的 dispatch 方法触发回调并清理 requestId 关联状态,
///   invokeMethod 本身返回 null(与既有的三个子窗口通道一致;平台层对这类
///   调用均为 fire-and-forget,不读返回值)。
///
/// `registerMessage` 直接返回 null(消息类型注册只作用于 Dart 层解码,
/// 原生侧已在主窗口完成注册);未注册的方法抛 [UnsupportedError];
/// [setMethodCallHandler] 空实现(子窗口不执行 ImclientPlatform.init,
/// 没有原生事件经此分发)。
class ProxyImclientChannel implements ImclientChannel {
  /// [eventPrefix] 为转发事件名前缀(如 'moment.imclient'),
  /// 与主窗口侧 proxy 注册的事件名一一对应。
  /// [tag]/[windowName] 仅用于日志与 [UnsupportedError] 文案,
  /// 子类传入各自的历史值以保持报错信息不变。
  ProxyImclientChannel(
    this.eventPrefix, {
    String? tag,
    String? windowName,
  })  : _tag = tag ?? 'ProxyImclientChannel',
        _windowName = windowName ?? 'sub';

  /// 转发事件名前缀,完整事件名为 `$eventPrefix.$method`。
  final String eventPrefix;

  final String _tag;
  final String _windowName;

  static const int _mainWindowId = 0;

  final Map<String, Future<dynamic> Function(dynamic args)> _forwards = {};

  /// 按原 args 转发 `method` 到 `$eventPrefix.$method`,回传主窗口结果。
  void forwardSimple(String method) => forward(method);

  /// 转发 `method` 到**共享** IM 代理域 `im.$method`(而非本窗口的
  /// `$eventPrefix.$method`),由主窗口的 MainImclientProxy 一处实现。
  ///
  /// 适用于各窗口共用的无副作用读接口(getUserInfo / getUserInfos /
  /// getGroupMembers / clientId / serverDeltaTime 等)。args 按 imclient 侧的
  /// 原始形状透传,不做整形——共享 handler 按参数超集读取。
  ///
  /// 仍需逐个显式声明:方法表是本窗口的权限白名单,未声明的方法会抛
  /// [UnsupportedError] 并带上窗口名,便于定位越权来源。
  void forwardShared(String method) =>
      forward(method, event: '$kSharedImEventPrefix.$method');

  /// 转发 `method`:先经 [reshapeArgs] 整形参数(缺省按原 args),
  /// 再发给主窗口并回传其结果。[event] 可覆盖事件名(缺省
  /// `$eventPrefix.$method`,用于方法与事件名不一致的个别接口)。
  void forward(
    String method, {
    String? event,
    dynamic Function(dynamic args)? reshapeArgs,
  }) {
    final eventName = event ?? '$eventPrefix.$method';
    _forwards[method] = (args) async {
      return await WindowEventChannel.invoke(
        _mainWindowId,
        eventName,
        reshapeArgs != null ? reshapeArgs(args) : args,
      );
    };
  }

  /// 回调式接口转发:从 args 取 requestId,[makeRequest] 可整形转发参数
  /// (缺省按原 args);主窗口返回结果后调用 [dispatch] 触发
  /// [ImclientPlatform] 的回调分发。invokeMethod 返回 null。
  void forwardWithRequestId(
    String method,
    void Function(int requestId, dynamic result) dispatch, {
    String? event,
    dynamic Function(dynamic args)? makeRequest,
  }) {
    final eventName = event ?? '$eventPrefix.$method';
    _forwards[method] = (args) async {
      final map = args as Map<dynamic, dynamic>;
      final requestId = map['requestId'] as int;
      final result = await WindowEventChannel.invoke(
        _mainWindowId,
        eventName,
        makeRequest != null ? makeRequest(map) : map,
      );
      dispatch(requestId, result);
      return null;
    };
  }

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    if (method == 'registerMessage') {
      // 消息类型注册只作用于 Dart 层解码,不通过 IM channel 传给原生;
      // 原生侧已在主窗口完成注册。
      return null;
    }
    final handler = _forwards[method];
    if (handler == null) {
      throw UnsupportedError(
        '$_tag method $method is not supported in $_windowName window',
      );
    }
    return await handler(arguments) as T?;
  }

  @override
  void setMethodCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    // 子窗口不执行 ImclientPlatform.init,没有原生事件经此 handler 分发;
    // 主窗口转发来的事件由各 WindowApp 直接处理。
  }

  // -------------------------------------------------------------- 常用 dispatch

  /// 字符串结果类接口(sendMomentsRequest/uploadMedia/getAuthorizedMediaUrl 等):
  /// 主窗口返回 `{errorCode, result}`,按 onOperationStringSuccess /
  /// onOperationFailure 的既有语义触发回调。
  static void dispatchStringResult(int requestId, dynamic result) {
    final errorCode = (result is Map) ? (result['errorCode'] as int? ?? -1) : -1;
    final raw = (result is Map) ? result['result'] : null;
    ImclientPlatform.dispatchStringResult(
        requestId, errorCode, result: raw is String ? raw : '');
  }

  /// 文件记录列表类接口(getConversationFiles/searchFiles):
  /// 主窗口返回 `{errorCode, files}`,按 onFilesResult 的语义触发回调。
  static void dispatchFilesResult(int requestId, dynamic result) {
    final errorCode = (result is Map) ? (result['errorCode'] as int? ?? -1) : -1;
    final files = (result is Map) ? result['files'] as List<dynamic>? : null;
    ImclientPlatform.dispatchOperationResult(requestId, errorCode, files: files);
  }

  /// 无参成功回调类接口(deleteFileRecord/configApplication):
  /// 主窗口返回 `{errorCode}`,按 onOperationVoidSuccess 的语义触发回调。
  static void dispatchVoidResult(int requestId, dynamic result) {
    final errorCode = (result is Map) ? (result['errorCode'] as int? ?? -1) : -1;
    ImclientPlatform.dispatchOperationResult(requestId, errorCode);
  }

  /// 会议请求(sendConferenceRequest):主窗口返回 `{errorCode, result}`,
  /// result 可能不是 String(如 Map),按既有语义统一成字符串后分发。
  static void dispatchConferenceResult(int requestId, dynamic result) {
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
    ImclientPlatform.dispatchConferenceRequestResult(
        requestId, errorCode, payload);
  }

  /// sendMessage 的异步结果:主窗口在服务器 ack/失败后经
  /// `im.onSendMessageResult` 回传 `{requestId, errorCode, messageUid,
  /// timestamp}`,这里按 onSendMessageSuccess/Failure 的既有语义触发回调、
  /// 更新发送中消息并清理 requestId 关联状态,与移动端一致。
  ///
  /// 注意这里的 requestId 是**本窗口**分配的:主窗口侧的成功/失败回调是闭包,
  /// 词法捕获了它,所以不存在跨窗口 requestId 撞号的问题。
  static void dispatchSendMessageResult(dynamic args) {
    if (args is! Map) return;
    final requestId = args['requestId'] as int?;
    if (requestId == null) return;
    ImclientPlatform.dispatchSendMessageResult(
      requestId,
      args['errorCode'] as int? ?? 0,
      messageUid: args['messageUid'] as int? ?? 0,
      timestamp: args['timestamp'] as int? ?? 0,
    );
  }
}
