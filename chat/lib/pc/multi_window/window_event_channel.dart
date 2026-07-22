import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 主窗口与各子窗口(通话、媒体预览等)之间的通信通道封装。
///
/// 基于 [DesktopMultiWindow.invokeMethod] 实现：
/// - 主窗口调用子窗口：invokeMethod(subWindowId, method, args)
/// - 子窗口调用主窗口：invokeMethod(0, method, args)
///
/// 跨窗口传递 Map/List/基本类型(method channel 原生支持),不做 JSON 字符串化;
/// [_encode]/[_decode] 只做类型归一化。
///
/// 注意:[listen] 底层是 [DesktopMultiWindow.setMethodHandler],**进程内全局唯一**。
/// 因此本类是每个 isolate 的单例:所有功能(通话代理、媒体预览……)把各自的
/// handler 注册到同一张表上,method 名用前缀区分,避免后注册者顶掉先注册者。
///
/// method 命名约定:`<domain>[.imclient].<method>`。domain 为窗口/功能域
/// (voip / mediaPreview / moment / search 等);转发 Imclient 调用的代理事件
/// 在 domain 后再加 `.imclient` 一段,如 `moment.imclient.getUserInfo`。
class WindowEventChannel {
  static const String _tag = 'WindowEventChannel';

  static final WindowEventChannel _instance = WindowEventChannel._();

  factory WindowEventChannel() => _instance;

  WindowEventChannel._();

  final Map<String, Future<dynamic> Function(dynamic args)> _handlers = {};

  /// 注册消息处理器。同一 method 重复注册会覆盖旧 handler,
  /// 覆盖前打告警日志(多半意味着前缀冲突或重复 install),不抛异常。
  void register(String method, Future<dynamic> Function(dynamic args) handler) {
    if (_handlers.containsKey(method)) {
      debugPrint('$_tag register $method: overriding existing handler');
    }
    _handlers[method] = handler;
  }

  /// 取消注册消息处理器。
  void unregister(String method) {
    _handlers.remove(method);
  }

  /// 开始监听跨窗口消息。可重复调用(幂等)。
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
