import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 当前的音频输出设备。目前只有播放语音消息时用到，对应原生侧
/// `AudioOutputChannel`(Android) 与 `AppDelegate`(iOS)。
abstract final class AudioOutputDevice {
  static const MethodChannel _channel =
      MethodChannel('chat.wildfire/audio_output');

  /// 当前是否接着耳机(有线/USB/蓝牙/助听器)。
  ///
  /// 只是一次性查询，不跟踪热插拔；桌面/鸿蒙没有实现，返回 false(即按"没接耳机"处理，
  /// 而它们本来也切不到听筒)。
  static Future<bool> isHeadsetOn() async {
    try {
      return await _channel.invokeMethod<bool>('isHeadsetOn') ?? false;
    } catch (e) {
      // 桌面/鸿蒙没有实现，MissingPluginException 走到这里
      debugPrint('查询音频输出设备失败: $e');
      return false;
    }
  }
}
