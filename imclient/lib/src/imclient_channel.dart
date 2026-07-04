import 'package:flutter/services.dart';

/// imclient 平台通道抽象。
///
/// 移动端（Android/iOS/鸿蒙）由 [MethodChannelImclientChannel] 走真实的
/// MethodChannel 与原生 SDK 通信；桌面端（macOS/Windows/Linux）由
/// ImclientFfiChannel 通过 dart:ffi 直接驱动 libMarsWrapper，两者对上层
/// （imclient_method_channel.dart）暴露完全一致的 invokeMethod / 回调契约，
/// 上层代码无需感知差异。
abstract class ImclientChannel {
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]);

  void setMethodCallHandler(
      Future<dynamic> Function(MethodCall call)? handler);
}

/// 移动端实现：真实 MethodChannel 的薄适配。
class MethodChannelImclientChannel implements ImclientChannel {
  MethodChannelImclientChannel(this._channel);

  final MethodChannel _channel;

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    return _channel.invokeMethod<T>(method, arguments);
  }

  @override
  void setMethodCallHandler(
      Future<dynamic> Function(MethodCall call)? handler) {
    _channel.setMethodCallHandler(handler);
  }
}
