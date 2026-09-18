import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart' show Codec, FlutterSoundPlayer;
import 'package:imclient/imclient_platform.dart';
import 'package:logger/logger.dart' show Level;

/// 按住说话的震动反馈和发送语音的提示音，参考 android-chat
abstract final class VoiceRecordFeedback {
  static const String _sendSoundAsset = 'assets/sounds/voice_message_sent.mp3';

  // 和 android-chat 一样用很小的音量播放
  static const double _sendSoundVolume = 0.1;

  static Future<FlutterSoundPlayer>? _player;
  static Uint8List? _sendSound;

  /// 开始录音
  static void recordStarted() {
    // android-chat 是 40ms 的短震动；iOS 上 vibrate 是系统级的长震动，改用触感反馈
    if (WfcPlatform.isAndroid) {
      HapticFeedback.vibrate();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// 手指移到了另一个目标
  static void zoneChanged() {
    // Android 上 mediumImpact 就是 android-chat 用的 KEYBOARD_TAP；iOS 用轻一些的触感反馈
    if (WfcPlatform.isAndroid) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// 播放发送语音的提示音。移动端录音用的就是 flutter_sound，提示音也用它，
  /// 不另外引入播放器抢音频会话(语音消息的播放见 [VoiceMessagePlayer])
  static Future<void> playSendSound() async {
    final Future<FlutterSoundPlayer> opening = _player ??= _openPlayer();
    final FlutterSoundPlayer player;
    try {
      player = await opening;
    } catch (e) {
      debugPrint('打开提示音播放器失败: $e');
      _player = null;
      return;
    }
    try {
      final Uint8List sound = _sendSound ??=
          (await rootBundle.load(_sendSoundAsset)).buffer.asUint8List();
      // 开始播放之前设置的音量在开始播放时生效
      await player.setVolume(_sendSoundVolume);
      await player.startPlayer(fromDataBuffer: sound, codec: Codec.mp3);
    } catch (e) {
      debugPrint('播放发送提示音失败: $e');
    }
  }

  static Future<FlutterSoundPlayer> _openPlayer() async {
    final FlutterSoundPlayer player =
        FlutterSoundPlayer(logLevel: Level.warning);
    await player.openPlayer();
    return player;
  }
}
