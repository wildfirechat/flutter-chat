import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:imclient/imclient_platform.dart';
import 'package:path_provider/path_provider.dart';

import 'package:chat/asr/asr_error.dart';
import 'package:chat/asr/asr_manager.dart';
import 'package:chat/asr/pcm_audio_recorder.dart';
import 'package:chat/config.dart';
import 'pcm_wav_encoder.dart';
import 'voice_record_feedback.dart';
import 'voice_record_geometry.dart';

/// 按住说话的阶段
enum VoiceRecordStage {
  /// 空闲，浮层没有显示
  idle,

  /// 按住录音中
  recording,

  /// 在“转文字”上松手后，编辑识别出的文字
  editing,

  /// 松手之后，浮层正在退出，或者正在提示说话时间太短
  dismissing,
}

/// 气泡里的提示
enum VoiceBubbleHint {
  /// 说话时间太短
  tooShort,

  /// 没有识别到文字
  noText,

  /// 转文字失败
  recognizeFailed,
}

/// 按住说话，交互参考微信，移植自 android-chat 的 AudioRecorderPanel：
/// - 按住按钮开始录音，松开发送语音；
/// - 手指滑到左上方的“取消”后松开，不发送；
/// - 配置了实时语音识别服务时，手指滑到右上方的“转文字”，边说边显示识别出的文字；松开后可以编辑文字再发送，也可以发送原语音。
///
/// 录音采集 16kHz PCM，发送语音时再编码成 WAV；转文字识别的是从开始录音算起的全部音频。
/// 本类负责状态、录音、识别和发送，浮层界面见 VoiceRecordOverlay，按钮和手势见 VoiceRecordButton。
class VoiceRecordController extends ChangeNotifier {
  VoiceRecordController({
    required this.speechToTextEnabled,
    required this.onRecordStart,
    required this.onSendVoice,
    required this.onSendText,
    required this.onError,
  });

  /// 是否可以滑到“转文字”
  final bool speechToTextEnabled;

  /// 开始录音
  final VoidCallback onRecordStart;

  /// 发送语音：WAV 文件路径和时长（秒）。录音停止、编码完成后才回调，这时浮层可能已经关闭
  final void Function(String path, int duration) onSendVoice;

  /// 语音转成文字后，用户确认发送文字
  final ValueChanged<String> onSendText;

  /// 录音失败，需要提示用户。用户取消时不回调
  final ValueChanged<AsrError> onError;

  static const int _pcmBytesPerSecond = PcmAudioRecorder.sampleRate * 2;
  static const Duration _minDuration = Duration(seconds: 1);

  // 录音剩余多少时间时开始倒计时
  static const Duration _countDown = Duration(seconds: 10);
  static const Duration _tickInterval = Duration(milliseconds: 100);

  // 提示说话时间太短之后多久关闭浮层
  static const Duration _tooShortTipDuration = Duration(seconds: 1);

  VoiceRecordStage _stage = VoiceRecordStage.idle;
  _Recording? _recording;
  Duration _recordDuration = Duration.zero;
  Timer? _tickTimer;
  Timer? _dismissTimer;

  AsrManager? _asrManager;
  bool _asrStarted = false;
  bool _asrFinished = false;
  bool _asrFailed = false;

  VoiceRecordZone _zone = VoiceRecordZone.send;
  VoiceBubbleState _bubbleState = VoiceBubbleState.send;
  VoiceBubbleHint? _hint;
  int? _countDownSeconds;
  bool _waveLoading = false;
  bool _textEditable = false;
  bool _exiting = false;
  bool _disposed = false;

  /// 当前音量，0~1，驱动声波
  final ValueNotifier<double> level = ValueNotifier<double>(0);

  /// 气泡里识别出的文字，编辑文字时用户可以修改
  final TextEditingController textController = TextEditingController();

  VoiceRecordStage get stage => _stage;

  /// 手指所在的目标
  VoiceRecordZone get zone => _zone;

  VoiceBubbleState get bubbleState => _bubbleState;

  VoiceBubbleHint? get hint => _hint;

  /// 最长录音时间快到时剩余的秒数，还没开始倒计时为 null
  int? get countDownSeconds => _countDownSeconds;

  /// 录音已经停止，声波换成等待识别结果的动画
  bool get waveLoading => _waveLoading;

  /// 转文字已经结束（完成或出错）
  bool get asrFinished => _asrFinished;

  /// 识别结果全部返回，可以编辑文字
  bool get textEditable => _textEditable;

  /// 正在播放退出动画，播放完后浮层调用 [dismissNow]
  bool get isExiting => _exiting;

  /// 按住转文字时出错，在气泡的文字处提示；松手后没有文字时换成红色的提示气泡
  bool get showsRecognizeFailedInText =>
      _asrFailed && _stage == VoiceRecordStage.recording;

  /// 编辑文字时是否可以发送原语音
  bool get isVoiceAvailable {
    final _Recording? recording = _recording;
    return recording != null &&
        recording.bytes > 0 &&
        _recordDuration >= _minDuration;
  }

  /// 编辑文字时是否可以发送文字
  bool get canSendText =>
      _asrFinished && textController.text.trim().isNotEmpty;

  static Duration get _maxDuration =>
      Duration(seconds: Config.MAX_AUDIO_RECORD_TIME_SECOND);

  /// 发送语音时音量放大的倍数，见 [Config.ENABLE_AUDIO_MESSAGE_AMPLIFICATION]
  static int get _audioGain =>
      WfcPlatform.isAndroid && Config.ENABLE_AUDIO_MESSAGE_AMPLIFICATION
          ? math.max(1, Config.AUDIO_MESSAGE_AMPLIFICATION_FACTOR)
          : 1;

  /// 按下按钮：开始录音，显示浮层
  void start() {
    if (_stage == VoiceRecordStage.dismissing) {
      // 上一次录音的浮层还在退出，直接关闭
      dismissNow();
    }
    if (_stage != VoiceRecordStage.idle) {
      return;
    }
    final _Recording recording = _Recording(PcmAudioRecorder());
    _recording = recording;
    _recordDuration = Duration.zero;
    _stage = VoiceRecordStage.recording;
    _asrStarted = false;
    _asrFinished = false;
    _asrFailed = false;
    _zone = VoiceRecordZone.send;
    _bubbleState = VoiceBubbleState.send;
    _hint = null;
    _countDownSeconds = null;
    _waveLoading = false;
    _textEditable = false;
    _exiting = false;
    level.value = 0;
    textController.clear();

    unawaited(recording.recorder.start(
      onFrame: (frame) => _handleAudioData(recording, frame),
      onError: (error) => _handleRecorderError(recording, error),
    ));
    _tickTimer = Timer.periodic(_tickInterval, (_) => _tick());
    VoiceRecordFeedback.recordStarted();
    onRecordStart();
    _notify();
  }

  /// 手指移到了 [zone]
  void updateZone(VoiceRecordZone zone) {
    if (_stage != VoiceRecordStage.recording || zone == _zone) {
      return;
    }
    _zone = zone;
    VoiceRecordFeedback.zoneChanged();
    switch (zone) {
      case VoiceRecordZone.cancel:
        _bubbleState = VoiceBubbleState.cancel;
      case VoiceRecordZone.text:
        _startSpeechToText();
        _bubbleState = VoiceBubbleState.text;
      case VoiceRecordZone.send:
        _bubbleState = VoiceBubbleState.send;
    }
    _notify();
  }

  /// 松开手指：按手指所在的目标结束录音
  void release() {
    if (_stage == VoiceRecordStage.recording) {
      _stopRecord(_zone);
    }
  }

  /// 编辑文字时点“取消”
  void cancelEditing() {
    if (_stage != VoiceRecordStage.editing) {
      return;
    }
    _cancelSpeechToText();
    _dismissPopup();
  }

  /// 编辑文字时点“发送原语音”
  void sendVoiceFromEditing() {
    final _Recording? recording = _recording;
    if (_stage != VoiceRecordStage.editing ||
        recording == null ||
        !isVoiceAvailable) {
      return;
    }
    _cancelSpeechToText();
    unawaited(_sendVoice(recording));
    _dismissPopup();
  }

  /// 编辑文字时点“发送”
  void sendText() {
    if (_stage != VoiceRecordStage.editing || !canSendText) {
      return;
    }
    onSendText(textController.text.trim());
    _dismissPopup();
  }

  /// 返回键，等同于取消。浮层没有显示时返回 false
  bool handleBack() {
    switch (_stage) {
      case VoiceRecordStage.idle:
        return false;
      case VoiceRecordStage.recording:
        _stopRecord(VoiceRecordZone.cancel);
      case VoiceRecordStage.editing:
        cancelEditing();
      case VoiceRecordStage.dismissing:
        if (!_exiting) {
          _dismissPopup();
        }
    }
    return true;
  }

  /// 立即关闭浮层，停止录音和识别，不发送。已经开始发送的语音照常发送
  void dismissNow() {
    _dismissTimer?.cancel();
    _tickTimer?.cancel();
    if (_stage == VoiceRecordStage.idle) {
      return;
    }
    _stage = VoiceRecordStage.idle;
    final _Recording? recording = _recording;
    _recording = null;
    unawaited(recording?.stop());
    _cancelSpeechToText();
    _exiting = false;
    _textEditable = false;
    _notify();
  }

  void _handleAudioData(_Recording recording, Uint8List frame) {
    // 停止录音之后到达的音频也要，发送语音时等它们全部到达
    recording.add(frame);
    if (!identical(_recording, recording)) {
      return;
    }
    if (_stage == VoiceRecordStage.recording) {
      level.value = _computeLevel(frame);
    }
    _asrManager?.feedAudioData(frame);
  }

  void _handleRecorderError(_Recording recording, AsrError error) {
    if (!identical(_recording, recording) ||
        _stage != VoiceRecordStage.recording) {
      return;
    }
    debugPrint('录音失败: $error');
    if (recording.bytes > 0) {
      // 例如来电抢走了麦克风，按手指当前的位置结束录音，保留已经录到的声音
      _stopRecord(_zone);
    } else {
      onError(error);
      _dismissPopup();
    }
  }

  void _tick() {
    final _Recording? recording = _recording;
    if (_stage != VoiceRecordStage.recording || recording == null) {
      _tickTimer?.cancel();
      return;
    }
    final Duration elapsed = recording.stopwatch.elapsed;
    final Duration maxDuration = _maxDuration;
    if (elapsed >= maxDuration) {
      _stopRecord(_zone);
      return;
    }
    if (elapsed > maxDuration - _countDown) {
      final int seconds =
          ((maxDuration - elapsed).inMilliseconds / 1000).ceil();
      if (seconds != _countDownSeconds) {
        _countDownSeconds = seconds;
        _notify();
      }
    }
  }

  /// 结束录音，[zone] 是松手时手指所在的目标
  void _stopRecord(VoiceRecordZone zone) {
    final _Recording? recording = _recording;
    if (_stage != VoiceRecordStage.recording || recording == null) {
      return;
    }
    _tickTimer?.cancel();
    _recordDuration = recording.stopwatch.elapsed;
    recording.stopwatch.stop();
    // 停止之前已经录到的音频还会陆续到达，发送语音、转文字都等它们到达之后再继续
    unawaited(recording.stop());
    if (zone == VoiceRecordZone.text) {
      _stage = VoiceRecordStage.editing;
      _enterEditing(recording);
      return;
    }
    _stage = VoiceRecordStage.dismissing;
    _cancelSpeechToText();
    if (zone == VoiceRecordZone.cancel) {
      _dismissPopup();
    } else if (_recordDuration < _minDuration) {
      _showTooShortTip();
    } else {
      unawaited(_sendVoice(recording));
      _dismissPopup();
    }
  }

  /// 等录音停止后把录到的音频编码成 WAV 文件发送
  Future<void> _sendVoice(_Recording recording) async {
    unawaited(VoiceRecordFeedback.playSendSound());
    await recording.stop();
    final Uint8List pcm = recording.toPcm();
    if (pcm.isEmpty) {
      return;
    }
    final int duration =
        math.max(1, (pcm.length / _pcmBytesPerSecond).round());
    try {
      final Directory directory = await getTemporaryDirectory();
      final String path =
          '${directory.path}/voice-${DateTime.now().millisecondsSinceEpoch}.wav';
      await PcmWavEncoder.encodeToFile(pcm, path, gain: _audioGain);
      onSendVoice(path, duration);
    } catch (e) {
      debugPrint('编码语音失败: $e');
      onError(AsrError(AsrErrorKind.recordFailed, '$e'));
    }
  }

  void _startSpeechToText() {
    if (_asrStarted) {
      return;
    }
    _asrStarted = true;
    final AsrManager manager = AsrManager();
    _asrManager = manager;
    manager.startRecognitionWithAudioFeed(
      onPartialResult: (text) {
        if (identical(_asrManager, manager)) {
          _onSpeechText(text, isFinal: false);
        }
      },
      onFinalResult: (text) {
        if (identical(_asrManager, manager)) {
          _onSpeechText(text, isFinal: true);
        }
      },
      onError: (error) {
        if (identical(_asrManager, manager)) {
          _onSpeechError(error);
        }
      },
    );
    // 转文字从开始录音时算起，先补上已经录到的音频
    final _Recording? recording = _recording;
    if (identical(_asrManager, manager) && recording != null) {
      for (final Uint8List frame in recording.frames) {
        manager.feedAudioData(frame);
      }
    }
  }

  void _onSpeechText(String text, {required bool isFinal}) {
    if (isFinal) {
      _asrFinished = true;
      _asrManager = null;
    }
    if (textController.text != text) {
      textController.value = TextEditingValue(
          text: text, selection: TextSelection.collapsed(offset: text.length));
    }
    if (isFinal && _stage == VoiceRecordStage.editing) {
      _onRecognitionDoneInEditing();
    } else {
      _notify();
    }
  }

  void _onSpeechError(AsrError error) {
    debugPrint('转文字失败: $error');
    // 已经识别出的文字保留，仍然可以编辑后发送
    _asrFailed = textController.text.isEmpty;
    _asrFinished = true;
    _asrManager = null;
    if (_stage == VoiceRecordStage.editing) {
      _onRecognitionDoneInEditing();
    } else {
      _notify();
    }
  }

  void _cancelSpeechToText() {
    final AsrManager? manager = _asrManager;
    _asrManager = null;
    manager?.cancelRecognition();
  }

  /// 在“转文字”上松手：底部按钮落下，换成取消、发送原语音、发送；识别结果全部返回后可以编辑文字
  void _enterEditing(_Recording recording) {
    final AsrManager? manager = _asrManager;
    if (manager == null) {
      // 识别已经结束，或者出错了
      _asrFinished = true;
      _onRecognitionDoneInEditing();
      return;
    }
    // 声波换成等待动画。录到的音频全部提供给识别服务之后再停止，剩余识别结果返回后回调 onFinalResult
    _waveLoading = true;
    _bubbleState = VoiceBubbleState.edit;
    recording.stop().then((_) {
      if (identical(_asrManager, manager)) {
        manager.stopRecognition();
      }
    });
    _notify();
  }

  void _onRecognitionDoneInEditing() {
    _waveLoading = false;
    if (textController.text.isEmpty) {
      // 没有识别到文字：红色提示，只能取消或者发送原语音
      _hint = _asrFailed
          ? VoiceBubbleHint.recognizeFailed
          : VoiceBubbleHint.noText;
      _bubbleState = VoiceBubbleState.noText;
    } else {
      _textEditable = true;
      _bubbleState = VoiceBubbleState.edit;
    }
    _notify();
  }

  void _showTooShortTip() {
    _hint = VoiceBubbleHint.tooShort;
    _bubbleState = VoiceBubbleState.tooShort;
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_tooShortTipDuration, _dismissPopup);
    _notify();
  }

  /// 播放退出动画，播放完后浮层调用 [dismissNow] 关闭
  void _dismissPopup() {
    _dismissTimer?.cancel();
    if (_stage == VoiceRecordStage.idle) {
      return;
    }
    _stage = VoiceRecordStage.dismissing;
    _exiting = true;
    _textEditable = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    dismissNow();
    _disposed = true;
    level.dispose();
    textController.dispose();
    super.dispose();
  }

  /// 一段 PCM 的音量，0~1
  static double _computeLevel(Uint8List pcm) {
    final int samples = pcm.length ~/ 2;
    if (samples == 0) {
      return 0;
    }
    final ByteData data = ByteData.sublistView(pcm);
    double sum = 0;
    for (int i = 0; i < samples; i++) {
      final int sample = data.getInt16(i * 2, Endian.little);
      sum += sample * sample;
    }
    // 发送时会放大音量，声波按放大后的音量显示
    final double db =
        20 * _log10(math.max(math.sqrt(sum / samples), 1.0) / 32768) +
            20 * _log10(_audioGain.toDouble());
    // -50dB 以下视为安静，-15dB 以上视为最大音量
    return ((db + 50) / 35).clamp(0.0, 1.0);
  }

  static double _log10(double value) => math.log(value) / math.ln10;
}

/// 一次录音。发送语音要等录音停止、音频全部到达之后再编码，这时浮层可能已经关闭，录到的音频跟着这个对象走
class _Recording {
  _Recording(this.recorder);

  final PcmAudioRecorder recorder;
  final Stopwatch stopwatch = Stopwatch()..start();
  final List<Uint8List> frames = <Uint8List>[];
  int bytes = 0;
  Future<void>? _stopping;

  void add(Uint8List frame) {
    frames.add(frame);
    bytes += frame.length;
  }

  /// 停止录音，返回时停止之前录到的音频都已经到达
  Future<void> stop() => _stopping ??= recorder.stop();

  /// 录到的全部音频
  Uint8List toPcm() {
    final Uint8List pcm = Uint8List(bytes);
    int offset = 0;
    for (final Uint8List frame in frames) {
      pcm.setRange(offset, offset + frame.length, frame);
      offset += frame.length;
    }
    return pcm;
  }
}
