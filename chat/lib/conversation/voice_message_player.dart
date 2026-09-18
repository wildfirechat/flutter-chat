import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:avenginekit/engine/call_state.dart';
import 'package:avenginekit/internal/avenginekit_impl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart'
    show FlutterSoundPlayer, PlaybackDisposition;
import 'package:chat/utils/audio_output_device.dart';
import 'package:chat/utils/proximity_monitor.dart';
import 'package:imclient/imclient_platform.dart';
import 'package:logger/logger.dart' show Level;
import 'package:shared_preferences/shared_preferences.dart';

/// 语音消息的播放方式(扬声器/听筒)。全局设置并持久化，重启后保持生效，
/// 参考 android-chat 的 `AudioPlayModeUtils`。
abstract final class VoicePlayMode {
  static const String _earpiecePrefKey = 'audio_play_in_earpiece';

  /// 设置本身。会话标题上的听筒图标、设置页的开关、长按菜单都跟着它变，
  /// 所以做成可监听的：菜单和设置页是两个入口，改一边另一边要立刻同步。
  static final ValueNotifier<bool> listenable = ValueNotifier<bool>(false);

  static bool get _earpiece => listenable.value;

  /// 能否切到听筒播放：
  /// - 桌面端(含鸿蒙电脑)没有听筒；
  /// - iPad 也没有听筒(Android 平板按 sw600dp 判定，折叠屏等仍有听筒，不排除)；
  /// - 鸿蒙的 flutter_sound 播放器把音频流写死成了媒体流(STREAM_USAGE_MUSIC)，
  ///   应用层切不到听筒。
  static bool get isSupported =>
      (WfcPlatform.isAndroid || WfcPlatform.isIOS) &&
      !(WfcPlatform.isIOS && WfcPlatform.isTablet);

  /// true 表示用听筒播放，false 表示用扬声器播放(默认)。
  static bool get isEarpiece => isSupported && _earpiece;

  /// 读出持久化的设置。菜单要同步取值，须在首帧之前调用。
  static Future<void> load() async {
    if (!isSupported) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    listenable.value = prefs.getBool(_earpiecePrefKey) ?? false;
  }

  static Future<void> setEarpiece(bool earpiece) async {
    listenable.value = earpiece;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_earpiecePrefKey, earpiece);
  }
}

/// 语音消息播放器，屏蔽各端播放实现与输出通道(扬声器/听筒)的差异。
///
/// 播放实现按平台分两路：
/// - **iOS/鸿蒙**用 `flutter_sound`：iOS 的输出通道由全局 AVAudioSession 的 category
///   决定，与用哪个播放器无关，因此不必换播放器；鸿蒙也只有 flutter_sound 有适配。
/// - **Android/桌面端**用 `audioplayers`：桌面端 flutter_sound 根本没有实现；Android 上
///   听筒播放要让播放器自己走通话流(USAGE_VOICE_COMMUNICATION，等价于 android-chat 里的
///   STREAM_VOICE_CALL)，这样音量键调的才是正在播放的那路音量，而 flutter_sound 不支持
///   指定音频流类型。
///
/// 输出通道通过 audioplayers 的 [AudioContext] 下发，它在两端落到的是不同东西：
/// Android 上是播放器的 AudioAttributes + 全局音频模式，iOS 上就是全局 AVAudioSession。
/// 两者都是全局状态，所以播放结束后必须恢复，否则之后 App 里别的声音也会从听筒出来。
class VoiceMessagePlayer {
  /// 扬声器播放。Android：媒体流 + 普通音频模式；iOS：playback(与 audioplayers 插件
  /// 初始化时设置的一致，即 App 的基线状态)。
  static final AudioContext _speakerContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      audioMode: AndroidAudioMode.normal,
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.media,
      // 与 android-chat 一致用短暂焦点：播完别的 App 的音乐能自己恢复
      audioFocus: AndroidAudioFocus.gainTransient,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
  );

  /// 听筒播放。Android：通话流 + 通信音频模式 + 关闭免提(与 android-chat 相同)；
  /// iOS：playAndRecord 且不加 defaultToSpeaker，即默认路由到听筒；
  /// 允许 A2DP 是为了接了蓝牙耳机时声音仍走耳机。
  static final AudioContext _earpieceContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      audioMode: AndroidAudioMode.inCommunication,
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.voiceCommunication,
      audioFocus: AndroidAudioFocus.gainTransient,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playAndRecord,
      options: const {AVAudioSessionOptions.allowBluetoothA2DP},
    ),
  );

  /// 通话中：音频模式(Android)/音频会话(iOS)归通话管，改了会把通话的声音切走，
  /// 所以这期间一律不动输出通道，语音消息跟着通话当前的通道播。
  static bool get _isInCall =>
      avEngineKit.currentSession != null &&
      avEngineKit.currentSession!.status != CallState.STATUS_IDLE;

  /// 本次播放是否真的会从听筒出声。用于决定要不要提示"请贴近手机聆听"。
  static Future<bool> willPlayThroughEarpiece() async {
    if (!VoicePlayMode.isEarpiece || _isInCall) {
      return false;
    }
    return !await AudioOutputDevice.isHeadsetOn();
  }

  FlutterSoundPlayer? _flutterSoundPlayer;
  AudioPlayer? _audioPlayer;
  StreamSubscription<void>? _completeSubscription;

  /// flutter_sound 取当前进度只能靠 onProgress 回调攒着(getProgress 已废弃)，
  /// 距离传感器切回扬声器时要用它接着播
  StreamSubscription<PlaybackDisposition>? _progressSubscription;
  Duration _flutterSoundPosition = Duration.zero;

  /// 最近一次下发的输出通道；null 表示本播放器还没动过，系统处于 App 的基线状态。
  AudioContext? _appliedContext;

  /// 正在播放的语音；null 表示当前没有在播
  String? _playingUrl;
  VoidCallback? _onComplete;

  /// 距离传感器把输出通道临时切成了听筒(用户设置仍是扬声器)
  bool _proximityEarpiece = false;

  /// 本次播放开始时有没有接耳机。见 [_contextFor]
  bool _headsetOn = false;

  /// 串行化各个操作。切换输出通道要「停掉 → 改通道 → 重新开始」，与并发进来的
  /// play/stop 交叠会错乱(停了又被拉起来、或者播两路)，所以排队执行。
  Future<void> _pending = Future<void>.value();

  static bool get _useFlutterSound => WfcPlatform.isIOS || WfcPlatform.isOhos;

  /// 播放 [url]，播放自然结束时回调 [onComplete]；中途被 [stop] 停掉不回调。
  Future<void> play(String url, {required VoidCallback onComplete}) =>
      _serialize(() => _play(url, onComplete));

  Future<void> stop() => _serialize(_stop);

  void dispose() {
    unawaited(_serialize(_dispose));
  }

  Future<void> _serialize(Future<void> Function() action) {
    final Future<void> next = _pending.then((_) => action());
    // 单个操作失败不能连累后面排队的操作
    _pending = next.catchError((Object e) => debugPrint('语音播放操作失败: $e'));
    return next;
  }

  Future<void> _play(String url, VoidCallback onComplete) async {
    _playingUrl = url;
    _onComplete = onComplete;
    _proximityEarpiece = false;
    _headsetOn = await AudioOutputDevice.isHeadsetOn();
    await _applyAudioContext(_contextFor(VoicePlayMode.isEarpiece));
    await _startPlayback(url, Duration.zero, onComplete);
    // 桌面/鸿蒙/平板切不了听筒，也就不用监听距离传感器；接了耳机同理，而且耳机多半在
    // 兜里或桌上，传感器被遮住只会误息屏
    if (VoicePlayMode.isSupported && !_headsetOn) {
      await ProximityMonitor.start(_onProximityChanged);
    }
  }

  /// 本次播放该用哪套输出通道。
  ///
  /// 接了耳机时听筒那套不但没意义，还有害：Android 的通话流走 STRATEGY_PHONE，
  /// 而该策略不使用 A2DP 蓝牙耳机(那是 SCO 的事)，声音会从听筒而不是耳机出来；
  /// iOS 的 playAndRecord 则会白白打开麦克风。统一退回扬声器那套——它走媒体流/
  /// playback，接了耳机声音照样从耳机出。
  AudioContext _contextFor(bool earpiece) =>
      earpiece && !_headsetOn ? _earpieceContext : _speakerContext;

  Future<void> _stop() async {
    _playingUrl = null;
    _onComplete = null;
    _proximityEarpiece = false;
    await ProximityMonitor.stop(_onProximityChanged);
    await _stopPlayback();
    if (_appliedContext != null) {
      await _applyAudioContext(_speakerContext);
    }
  }

  Future<void> _dispose() async {
    try {
      // 先 stop：既停掉播放，也把听筒模式改过的全局状态恢复回去
      await _stop();
      // stopPlayer 仅停止播放,closePlayer 才真正释放底层播放器资源
      await _flutterSoundPlayer?.closePlayer();
      await _audioPlayer?.dispose();
    } catch (e) {
      debugPrint('释放语音播放器失败: $e');
    }
  }

  Future<void> _startPlayback(
      String url, Duration position, VoidCallback onComplete) async {
    if (_useFlutterSound) {
      final player =
          _flutterSoundPlayer ??= FlutterSoundPlayer(logLevel: Level.error);
      await player.openPlayer();
      await player.setSubscriptionDuration(const Duration(milliseconds: 200));
      _flutterSoundPosition = position;
      _progressSubscription = player.onProgress
          ?.listen((disposition) => _flutterSoundPosition = disposition.position);
      await player.startPlayer(fromURI: url, whenFinished: onComplete);
      if (position > Duration.zero) {
        await player.seekToPlayer(position);
      }
    } else {
      final player = _audioPlayer ??= AudioPlayer();
      _completeSubscription =
          player.onPlayerComplete.listen((_) => onComplete());
      await player.play(UrlSource(url),
          position: position > Duration.zero ? position : null);
    }
  }

  Future<void> _stopPlayback() async {
    await _completeSubscription?.cancel();
    _completeSubscription = null;
    await _progressSubscription?.cancel();
    _progressSubscription = null;
    await _audioPlayer?.stop();
    final flutterSoundPlayer = _flutterSoundPlayer;
    if (flutterSoundPlayer != null && flutterSoundPlayer.isPlaying) {
      await flutterSoundPlayer.stopPlayer();
    }
  }

  Future<Duration> _currentPosition() async {
    try {
      if (_useFlutterSound) {
        return _flutterSoundPosition;
      }
      return await _audioPlayer?.getCurrentPosition() ?? Duration.zero;
    } catch (e) {
      debugPrint('读取语音播放进度失败: $e');
      return Duration.zero;
    }
  }

  void _onProximityChanged(bool near) {
    unawaited(_serialize(() => _applyProximity(near)));
  }

  /// 贴近手机时切听筒并从头重播(参考 android-chat：贴上来之前外放的那段多半没听清)，
  /// 离开时切回扬声器、接着当前位置继续。
  ///
  /// 用户已经手动选了听筒播放时不做通道切换，距离传感器只剩息屏的作用(原生侧负责)。
  /// 两端都是「停掉 → 改通道 → 重新开始」：Android 改 AudioAttributes 必须重建
  /// MediaPlayer，iOS 虽然改 category 就能直接切路由，但为了两端行为一致也走同一条路。
  Future<void> _applyProximity(bool near) async {
    final url = _playingUrl;
    final onComplete = _onComplete;
    if (url == null || onComplete == null) {
      return;
    }
    // 接了耳机时压根没注册传感器，这里只是兜底
    if (VoicePlayMode.isEarpiece || _headsetOn || _proximityEarpiece == near) {
      return;
    }
    _proximityEarpiece = near;
    final position = near ? Duration.zero : await _currentPosition();
    await _stopPlayback();
    await _applyAudioContext(_contextFor(near));
    await _startPlayback(url, position, onComplete);
  }

  Future<void> _applyAudioContext(AudioContext context) async {
    if (!VoicePlayMode.isSupported) {
      return;
    }
    if (_isInCall) {
      // 通话中不动输出通道。通话结束时通话自己会把音频模式/会话复位，这里记成"未知"，
      // 让通话结束后的下一次播放重新完整下发一遍，而不是被下面的相等判断跳过。
      _appliedContext = null;
      return;
    }
    if (_appliedContext == context) {
      return;
    }
    try {
      if (WfcPlatform.isAndroid) {
        // Android 上 AudioContext 是播放器级的(决定走媒体流还是通话流)，
        // 下发时顺带设置全局音频模式，所以必须发给真正播放的那个播放器实例
        await (_audioPlayer ??= AudioPlayer()).setAudioContext(context);
      } else {
        // iOS 上 AudioContext 就是全局 AVAudioSession，flutter_sound 播放时同样受它控制
        await AudioPlayer.global.setAudioContext(context);
      }
      _appliedContext = context;
    } catch (e) {
      debugPrint('设置语音消息输出通道失败: $e');
    }
  }
}
