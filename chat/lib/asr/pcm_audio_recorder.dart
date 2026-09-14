import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart'
    show AudioSource, Codec, FlutterSoundRecorder;
import 'package:imclient/imclient_platform.dart';
import 'package:logger/logger.dart' show Level;
import 'package:permission_handler/permission_handler.dart';
import 'package:record_platform_interface/record_platform_interface.dart'
    as record;

import 'asr_error.dart';

/// PCM 音频录制器，用于实时语音识别和按住说话
///
/// 采集 16kHz、16-bit、单声道 PCM（和 wf-voice 要求一致），每 30ms（960 字节）回调一帧。两套后端：
/// - Android/iOS/鸿蒙：flutter_sound 录到 Dart Stream；
/// - macOS/Windows/Linux：flutter_sound 没有桌面端实现，走 record 的桌面实现包。
///
/// 每次录音使用一个新实例。
abstract class PcmAudioRecorder {
  factory PcmAudioRecorder() => WfcPlatform.isNativeDesktop
      ? _RecordPcmAudioRecorder()
      : _FlutterSoundPcmAudioRecorder();

  static const int sampleRate = 16000;
  static const int frameBytes = 960;

  /// 开始录音。申请权限、打开麦克风都是异步的，失败时回调 [onError]
  Future<void> start({
    required ValueChanged<Uint8List> onFrame,
    required ValueChanged<AsrError> onError,
  });

  /// 停止录音，可以重复调用
  ///
  /// 底层在停止之前已经交付的音频会先回调完再返回，返回之后不再回调；不足一帧的尾巴丢弃
  Future<void> stop();
}

/// 底层回调的数据块大小不固定，重新切成 960 字节一帧：单条消息过大时 asr-api 或 wf-voice 会断开连接
class _PcmFramer {
  final Uint8List _frame = Uint8List(PcmAudioRecorder.frameBytes);
  int _offset = 0;

  void add(Uint8List data, ValueChanged<Uint8List> onFrame) {
    int index = 0;
    while (index < data.length) {
      final int count =
          math.min(_frame.length - _offset, data.length - index);
      _frame.setRange(_offset, _offset + count, data, index);
      _offset += count;
      index += count;
      if (_offset == _frame.length) {
        // 帧会被缓存，每帧复制一份
        onFrame(Uint8List.fromList(_frame));
        _offset = 0;
      }
    }
  }
}

class _FlutterSoundPcmAudioRecorder implements PcmAudioRecorder {
  // 每次回调的字节数，60ms。默认的 8192 字节是 256ms 回调一次，声波一顿一顿的，松手时丢掉的尾巴也长。
  // Android 实际按 max(系统最小缓冲区 × 2, bufferSize) 读取；iOS 是音频引擎 tap 的帧数，系统可能按自己的下限回调
  static const int _bufferSize = PcmAudioRecorder.frameBytes * 2;

  final _PcmFramer _framer = _PcmFramer();
  FlutterSoundRecorder? _recorder;
  StreamController<Uint8List>? _pcmController;

  // 为 null 时不再回调音频
  ValueChanged<Uint8List>? _onFrame;
  bool _stopped = false;
  Future<void>? _stopping;

  @override
  Future<void> start({
    required ValueChanged<Uint8List> onFrame,
    required ValueChanged<AsrError> onError,
  }) async {
    _onFrame = onFrame;
    try {
      final PermissionStatus status = await Permission.microphone.request();
      if (_stopped) {
        return;
      }
      if (!status.isGranted) {
        _onFrame = null;
        onError(const AsrError(AsrErrorKind.noPermission));
        return;
      }

      // 下面每次 await 期间都可能被 stop()，stop() 负责释放已经赋值的 _recorder/_pcmController
      final FlutterSoundRecorder recorder =
          FlutterSoundRecorder(logLevel: Level.warning);
      _recorder = recorder;
      await recorder.openRecorder();
      if (_stopped) {
        return;
      }

      final StreamController<Uint8List> pcmController =
          StreamController<Uint8List>();
      _pcmController = pcmController;
      pcmController.stream.listen((data) {
        final ValueChanged<Uint8List>? onFrame = _onFrame;
        if (onFrame != null) {
          _framer.add(data, onFrame);
        }
      });
      await recorder.startRecorder(
        codec: Codec.pcm16,
        sampleRate: PcmAudioRecorder.sampleRate,
        numChannels: 1,
        bufferSize: _bufferSize,
        toStream: pcmController.sink,
        // 和 android-chat 一致用通话音源，系统会做回声消除和降噪
        audioSource: WfcPlatform.isAndroid
            ? AudioSource.voice_communication
            : AudioSource.defaultSource,
      );
      debugPrint('录音已开始: ${PcmAudioRecorder.sampleRate}Hz, 16-bit, 单声道');
    } catch (e) {
      debugPrint('启动录音失败: $e');
      await _release();
      if (!_stopped) {
        _onFrame = null;
        onError(AsrError(AsrErrorKind.recordFailed, '$e'));
      }
    }
  }

  @override
  Future<void> stop() => _stopping ??= _stop();

  Future<void> _stop() async {
    _stopped = true;
    // 先停止录音再关闭 StreamController，close 返回时已经交付的音频都回调完了
    await _release();
    _onFrame = null;
  }

  Future<void> _release() async {
    final FlutterSoundRecorder? recorder = _recorder;
    final StreamController<Uint8List>? pcmController = _pcmController;
    _recorder = null;
    _pcmController = null;
    if (recorder != null) {
      // flutter_sound 内部串行化 open/start/stop/close，启动途中停止也是安全的
      try {
        await recorder.stopRecorder();
      } catch (e) {
        debugPrint('停止录音失败: $e');
      }
      try {
        await recorder.closeRecorder();
      } catch (e) {
        debugPrint('关闭录音失败: $e');
      }
    }
    // 录音停了再关，避免 flutter_sound 往已关闭的 sink 里写数据
    await pcmController?.close();
  }
}

class _RecordPcmAudioRecorder implements PcmAudioRecorder {
  static int _nextId = 0;

  final String _recorderId = 'asr-${_nextId++}';
  final _PcmFramer _framer = _PcmFramer();
  StreamSubscription<Uint8List>? _subscription;

  // 为 null 时不再回调音频
  ValueChanged<Uint8List>? _onFrame;
  bool _created = false;
  bool _stopped = false;
  Future<void>? _stopping;

  @override
  Future<void> start({
    required ValueChanged<Uint8List> onFrame,
    required ValueChanged<AsrError> onError,
  }) async {
    _onFrame = onFrame;
    final record.RecordPlatform platform = record.RecordPlatform.instance;
    try {
      await platform.create(_recorderId);
      _created = true;
      if (_stopped) {
        await _release();
        return;
      }
      // macOS 首次使用会弹系统授权框；Windows/Linux 直接返回 true
      if (!await platform.hasPermission(_recorderId)) {
        await _release();
        if (!_stopped) {
          _onFrame = null;
          onError(const AsrError(AsrErrorKind.noPermission));
        }
        return;
      }
      if (_stopped) {
        await _release();
        return;
      }
      final Stream<Uint8List> stream = await platform.startStream(
        _recorderId,
        const record.RecordConfig(
          encoder: record.AudioEncoder.pcm16bits,
          sampleRate: PcmAudioRecorder.sampleRate,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      if (_stopped) {
        await _release();
        return;
      }
      _subscription = stream.listen(
        (data) {
          final ValueChanged<Uint8List>? onFrame = _onFrame;
          if (onFrame != null) {
            _framer.add(data, onFrame);
          }
        },
        onError: (Object e) {
          debugPrint('录音出错: $e');
          if (!_stopped) {
            onError(AsrError(AsrErrorKind.recordFailed, '$e'));
          }
        },
      );
      debugPrint('录音已开始: ${PcmAudioRecorder.sampleRate}Hz, 16-bit, 单声道');
    } catch (e) {
      // Linux 上没有 parecord 命令（pulseaudio-utils）时也会走到这里
      debugPrint('启动录音失败: $e');
      await _release();
      if (!_stopped) {
        _onFrame = null;
        onError(AsrError(AsrErrorKind.recordFailed, '$e'));
      }
    }
  }

  @override
  Future<void> stop() => _stopping ??= _stop();

  Future<void> _stop() async {
    _stopped = true;
    await _release();
    _onFrame = null;
  }

  Future<void> _release() async {
    final StreamSubscription<Uint8List>? subscription = _subscription;
    _subscription = null;
    if (!_created) {
      await subscription?.cancel();
      return;
    }
    _created = false;
    final record.RecordPlatform platform = record.RecordPlatform.instance;
    try {
      await platform.stop(_recorderId);
    } catch (e) {
      debugPrint('停止录音失败: $e');
    }
    // 停止之后再取消订阅，停止期间交付的音频照常回调
    await subscription?.cancel();
    try {
      await platform.dispose(_recorderId);
    } catch (e) {
      debugPrint('释放录音失败: $e');
    }
  }
}
