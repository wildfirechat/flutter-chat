import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 距离传感器(贴近/离开)。目前只有播放语音消息时用到，对应原生侧
/// `ProximityChannel`(Android) 与 `AppDelegate`(iOS)。
///
/// **贴近时的息屏由原生侧负责**(Android 持有 PROXIMITY_SCREEN_OFF_WAKE_LOCK，
/// iOS 打开 proximityMonitoringEnabled，两者都是系统自己息屏/亮屏)，这里只把远近
/// 变化交给调用方，由它决定输出通道。
abstract final class ProximityMonitor {
  static const MethodChannel _channel =
      MethodChannel('chat.wildfire/proximity');

  static ValueChanged<bool>? _listener;
  static bool _handlerInstalled = false;

  /// 开始监听，远近变化时回调 [listener]。
  ///
  /// 返回 false 表示这台设备没有距离传感器(平板等)或平台没有实现(桌面/鸿蒙)，
  /// 调用方不应指望后续回调。同一时刻只支持一个 [listener]，后来者覆盖前者。
  static Future<bool> start(ValueChanged<bool> listener) async {
    _listener = listener;
    if (!_handlerInstalled) {
      _handlerInstalled = true;
      _channel.setMethodCallHandler(_onMethodCall);
    }
    try {
      return await _channel.invokeMethod<bool>('start') ?? false;
    } catch (e) {
      // 桌面/鸿蒙没有实现，MissingPluginException 走到这里
      debugPrint('开启距离传感器失败: $e');
      _listener = null;
      return false;
    }
  }

  /// 停止监听。[listener] 已被别人覆盖时不做任何事，避免把后来者的监听停掉。
  static Future<void> stop(ValueChanged<bool> listener) async {
    if (!identical(_listener, listener)) {
      return;
    }
    _listener = null;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e) {
      debugPrint('关闭距离传感器失败: $e');
    }
  }

  static Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'onProximityChanged') {
      _listener?.call(call.arguments == true);
    }
    return null;
  }
}
