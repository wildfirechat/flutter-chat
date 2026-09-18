import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 距离传感器(贴近/离开)。目前只有播放语音消息时用到，对应原生侧
/// `ProximityChannel`(Android) 与 `AppDelegate`(iOS)。
///
/// **贴近时的息屏由原生侧负责**(Android 持有 PROXIMITY_SCREEN_OFF_WAKE_LOCK，
/// iOS 打开 proximityMonitoringEnabled，两者都是系统自己息屏/亮屏)，这里只把远近
/// 变化交给调用方，由它决定输出通道。
///
/// 因此**开了必须关**：没关掉的话贴近息屏会在整个 App 里一直生效(播完语音之后
/// 看消息、翻列表都会被息屏)。[start] 发一个凭据，[stop] 认凭据；不要用监听回调
/// 本身当凭据：实例方法撕裂(`obj.method`)每次求值都是一个新的闭包对象，
/// `identical` 恒为 false(`==` 才为 true)，据此判断会让 stop 永远停不掉。
abstract final class ProximityMonitor {
  static const MethodChannel _channel =
      MethodChannel('chat.wildfire/proximity');

  /// 最近一次 [start] 发出的凭据，用来判断监听有没有被后来者接管
  static int _session = 0;

  /// 原生侧当前是否在监听。桌面/鸿蒙没有实现，恒为 false，
  /// 据此跳过注定抛 MissingPluginException 的 stop 调用。
  static bool _monitoring = false;

  static ValueChanged<bool>? _listener;
  static bool _handlerInstalled = false;

  /// 开始监听，远近变化时回调 [listener]。
  ///
  /// 返回本次监听的凭据，传给 [stop] 才能停掉这一次监听。返回 0 表示没开起来
  /// ——这台设备没有距离传感器(平板等)或平台没有实现(桌面/鸿蒙)，调用方不应
  /// 指望后续回调。同一时刻只支持一个 [listener]，后来者覆盖前者。
  static Future<int> start(ValueChanged<bool> listener) async {
    final int session = ++_session;
    _listener = listener;
    if (!_handlerInstalled) {
      _handlerInstalled = true;
      _channel.setMethodCallHandler(_onMethodCall);
    }
    try {
      if (await _channel.invokeMethod<bool>('start') ?? false) {
        _monitoring = true;
        return session;
      }
    } catch (e) {
      // 桌面/鸿蒙没有实现，MissingPluginException 走到这里
      debugPrint('开启距离传感器失败: $e');
    }
    // 没开起来。前一次若还在监听，按"后来者覆盖前者"一并停掉，别留个没人负责关的监听
    _listener = null;
    await _stopNative();
    return 0;
  }

  /// 停止 [session] 这一次监听。凭据已被后来者覆盖(或本来就没开起来)时什么都不做，
  /// 避免把后来者的监听停掉。
  static Future<void> stop(int session) async {
    if (session == 0 || session != _session) {
      return;
    }
    _listener = null;
    await _stopNative();
  }

  static Future<void> _stopNative() async {
    if (!_monitoring) {
      return;
    }
    _monitoring = false;
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
