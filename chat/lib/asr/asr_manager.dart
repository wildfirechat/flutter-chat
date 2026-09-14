import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';

import 'package:chat/config.dart';
import 'asr_auth.dart';
import 'asr_error.dart';
import 'asr_websocket_client.dart';
import 'pcm_audio_recorder.dart';

enum _AsrState {
  /// 空闲
  idle,

  /// 连接中，音频先缓存
  connecting,

  /// 已连接，录音中
  recording,

  /// 已停止录音，等待剩余识别结果
  finishing,
}

/// 实时语音识别管理器
///
/// 音频实时推送到 wf-voice 识别（经过 asr-api 转发，内网测试时也可以直连）。wf-voice 每识别完一句返回这句的最终结果；
/// 开启 [Config.ENABLE_ASR_PARTIAL_RESULT] 后，说话过程中还会返回正在说的这句的中间结果。音频有两种来源：
/// - [startRecognition]：自己录音，用于输入框的语音输入；
/// - [startRecognitionWithAudioFeed]：调用方通过 [feedAudioData] 提供，用于按住说话时转文字，录音由按住说话负责。
///
/// 服务地址见 [Config.ASR_STREAM_SERVER]。
class AsrManager {
  // 自己录音时的最长录音时长
  static const Duration _maxRecordingDuration = Duration(seconds: 60);

  // 停止录音后等待剩余识别结果的最长时间。服务端不支持 eos 指令时不会回复 [EOS]，靠它结束识别
  static const Duration _waitEosTimeout = Duration(seconds: 10);

  // 停止录音后一直没有新的识别结果，提前结束识别
  static const Duration _waitEosIdleTimeout = Duration(seconds: 15);

  // 停止录音后又收到识别结果，说明服务端还在识别，重新计算没有新结果就结束识别的时间
  static const Duration _waitEosIdleAfterResult = Duration(seconds: 60);

  _AsrState _state = _AsrState.idle;
  ValueChanged<String>? _onPartialResult;
  ValueChanged<String>? _onFinalResult;
  ValueChanged<AsrError>? _onError;
  PcmAudioRecorder? _audioRecorder;
  AsrWebSocketClient? _client;

  // 音频由调用方通过 feedAudioData 提供，而不是自己录音
  bool _feedAudio = false;

  // 调用方已经提供的音频字节数
  int _feedAudioBytes = 0;

  // 本次识别已确定的文本，即各句的最终结果
  String _recognizedText = '';

  // 正在说的这句的中间结果，收到这句的最终结果后清空
  String _partialText = '';

  // 连接成功前已经停止录音，连接成功后发送完缓存的音频再结束识别
  bool _pendingStop = false;
  Timer? _maxDurationTimer;
  Timer? _waitEosTimer;
  Timer? _waitEosIdleTimer;

  /// 是否正在识别，包括停止录音后等待剩余识别结果的阶段
  bool get isRecognizing => _state != _AsrState.idle;

  /// 开始语音识别并录音。会立即开始录音，连接识别服务期间录到的音频先缓存，连接成功后再发送。
  ///
  /// 识别完成或出错之后不再回调：
  /// - [onPartialResult]：识别文本有更新（识别出新的一句，或者正在说的这句有了新的中间结果），参数是本次识别到目前为止的全部文本；
  /// - [onFinalResult]：识别完成，参数是本次识别的全部文本，可能为空；
  /// - [onError]：出错。
  void startRecognition({
    required ValueChanged<String> onPartialResult,
    required ValueChanged<String> onFinalResult,
    required ValueChanged<AsrError> onError,
  }) {
    _start(onPartialResult, onFinalResult, onError, feedAudio: false);
  }

  /// 开始语音识别，由调用方通过 [feedAudioData] 提供音频，提供完后调用 [stopRecognition]。
  ///
  /// 连接识别服务期间提供的音频先缓存，连接成功后再发送。回调同 [startRecognition]
  void startRecognitionWithAudioFeed({
    required ValueChanged<String> onPartialResult,
    required ValueChanged<String> onFinalResult,
    required ValueChanged<AsrError> onError,
  }) {
    _start(onPartialResult, onFinalResult, onError, feedAudio: true);
  }

  void _start(
    ValueChanged<String> onPartialResult,
    ValueChanged<String> onFinalResult,
    ValueChanged<AsrError> onError, {
    required bool feedAudio,
  }) {
    if (_state != _AsrState.idle) {
      debugPrint('正在识别中，无需重复开始');
      return;
    }
    final String? url = Config.asrStreamServerUrl;
    if (url == null || url.isEmpty) {
      onError(const AsrError(AsrErrorKind.notConfigured));
      return;
    }

    _onPartialResult = onPartialResult;
    _onFinalResult = onFinalResult;
    _onError = onError;
    _feedAudio = feedAudio;
    _state = _AsrState.connecting;
    _recognizedText = '';
    _partialText = '';

    final AsrWebSocketClient client = AsrWebSocketClient(
      onConnected: () {
        _state = _AsrState.recording;
        if (_pendingStop) {
          _pendingStop = false;
          stopRecognition();
        }
      },
      onPartialResult: (text) {
        _delayIdleFinish();
        _partialText = text;
        _onPartialResult?.call(_text);
      },
      onResult: (text) {
        _delayIdleFinish();
        _partialText = '';
        _recognizedText = _join(_recognizedText, text);
        _onPartialResult?.call(_text);
      },
      onEos: _finishRecognition,
      onError: (error) {
        debugPrint('语音识别服务错误: $error');
        if (_state == _AsrState.finishing) {
          // 已经停止录音，保留已识别出的文本
          _finishRecognition();
        } else {
          _failRecognition(error);
        }
      },
    );
    _client = client;
    if (!feedAudio) {
      // 获取认证码、连接识别服务可能要一两秒，用户点完就开始说话。先开始录音，音频由 client 缓存到连接成功后发送
      _startAudioRecording(client);
    }

    // wf-voice 要求每个连接的 clientId 唯一，并会用作服务端录音文件名。连接 asr-api 时由 asr-api 重新生成
    final String clientId = '${Imclient.currentUserId}-${_randomId()}';
    if (!AsrAuth.isAsrApiUrl(url)) {
      // 直连 wf-voice，不需要鉴权
      unawaited(client.connect(url, clientId,
          partialResult: Config.ENABLE_ASR_PARTIAL_RESULT));
      return;
    }
    AsrAuth.getAuthCode().then((authCode) {
      // 获取认证码期间，识别可能已经停止或取消
      if (identical(_client, client)) {
        unawaited(client.connect(url, clientId,
            partialResult: Config.ENABLE_ASR_PARTIAL_RESULT,
            authCode: authCode));
      }
    }, onError: (Object error) {
      if (identical(_client, client)) {
        _failRecognition(error is AsrError
            ? error
            : AsrError(AsrErrorKind.authCodeFailed, '$error'));
      }
    });
  }

  /// 提供音频数据，只在 [startRecognitionWithAudioFeed] 之后、[stopRecognition] 之前有效
  ///
  /// [pcm] 是 16kHz、16-bit、单声道 PCM，按 30ms（960 字节）一段提供，调用之后不能再修改
  void feedAudioData(Uint8List pcm) {
    if (!_feedAudio ||
        _pendingStop ||
        (_state != _AsrState.connecting && _state != _AsrState.recording)) {
      return;
    }
    _client?.sendAudioData(pcm);
    _feedAudioBytes += pcm.length;
  }

  /// 停止录音或停止提供音频，剩余识别结果返回后回调 onFinalResult
  void stopRecognition() {
    switch (_state) {
      case _AsrState.connecting:
        if (_pendingStop) {
          return;
        }
        final bool hasAudio = _audioRecorder != null || _feedAudioBytes > 0;
        _stopAudioRecording();
        _maxDurationTimer?.cancel();
        if (!hasAudio) {
          debugPrint('还没有音频，结束识别');
          _finishRecognition();
          return;
        }
        // 连接成功后发送完缓存的音频再结束，一直连不上时超时
        debugPrint('停止录音，连接成功后再结束识别');
        _pendingStop = true;
        _waitEosTimer?.cancel();
        _waitEosTimer = Timer(_waitEosTimeout, () {
          debugPrint('连接语音识别服务超时');
          _failRecognition(const AsrError(AsrErrorKind.connectTimeout));
        });
      case _AsrState.recording:
        debugPrint('停止录音，等待剩余识别结果');
        _state = _AsrState.finishing;
        _stopAudioRecording();
        _maxDurationTimer?.cancel();
        _client?.sendEos();
        // 一次提供了较长的音频时，服务端需要更多时间识别。16kHz、16-bit 的音频每毫秒 32 字节，按音频时长增加等待时间
        final int audioMs = _feedAudioBytes ~/ 32;
        _waitEosTimer?.cancel();
        _waitEosTimer = Timer(
            _waitEosTimeout + Duration(milliseconds: audioMs ~/ 2), () {
          debugPrint('等待剩余识别结果超时，结束识别');
          _finishRecognition();
        });
        _waitEosIdleTimer?.cancel();
        _waitEosIdleTimer = Timer(
            _waitEosIdleTimeout + Duration(milliseconds: audioMs ~/ 10),
            _onWaitEosIdle);
      case _AsrState.idle:
      case _AsrState.finishing:
        break;
    }
  }

  /// 取消语音识别，丢弃还没返回的识别结果，之后不再回调
  void cancelRecognition() {
    if (_state != _AsrState.idle) {
      debugPrint('取消识别');
      _cleanup();
    }
  }

  void _startAudioRecording(AsrWebSocketClient client) {
    final PcmAudioRecorder recorder = PcmAudioRecorder();
    _audioRecorder = recorder;
    unawaited(recorder.start(
      onFrame: (frame) {
        // 实时发送到服务端，还没连接成功时 client 会先缓存。停止录音后底层还会交付已经录到的音频，
        // 这时可能已经发出 eos，丢弃
        if (identical(_audioRecorder, recorder)) {
          client.sendAudioData(frame);
        }
      },
      onError: (error) {
        // 忽略已经停止的录音报的错误
        if (identical(_audioRecorder, recorder)) {
          _failRecognition(error);
        }
      },
    ));
    _maxDurationTimer = Timer(_maxRecordingDuration, () {
      debugPrint('达到最大录音时长，自动停止');
      stopRecognition();
    });
  }

  void _stopAudioRecording() {
    final PcmAudioRecorder? recorder = _audioRecorder;
    _audioRecorder = null;
    if (recorder != null) {
      unawaited(recorder.stop());
    }
  }

  /// 停止录音后又收到识别结果，重新计算没有新结果就结束识别的时间
  void _delayIdleFinish() {
    if (_state == _AsrState.finishing) {
      _waitEosIdleTimer?.cancel();
      _waitEosIdleTimer = Timer(_waitEosIdleAfterResult, _onWaitEosIdle);
    }
  }

  void _onWaitEosIdle() {
    debugPrint('一直没有新的识别结果，结束识别');
    _finishRecognition();
  }

  /// 已确定的文本，加上正在说的这句的中间结果
  String get _text => _join(_recognizedText, _partialText);

  void _finishRecognition() {
    if (_state == _AsrState.idle) {
      return;
    }
    final ValueChanged<String>? onFinalResult = _onFinalResult;
    // wf-voice 会把句号替换成逗号，去掉结尾多余的逗号
    final String text = _text.replaceFirst(RegExp(r'[，,]+$'), '');
    _cleanup();
    onFinalResult?.call(text);
  }

  void _failRecognition(AsrError error) {
    if (_state == _AsrState.idle) {
      return;
    }
    final ValueChanged<AsrError>? onError = _onError;
    _cleanup();
    onError?.call(error);
  }

  void _cleanup() {
    _state = _AsrState.idle;
    _onPartialResult = null;
    _onFinalResult = null;
    _onError = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _waitEosTimer?.cancel();
    _waitEosTimer = null;
    _waitEosIdleTimer?.cancel();
    _waitEosIdleTimer = null;
    _stopAudioRecording();
    _client?.disconnect();
    _client = null;
    _recognizedText = '';
    _partialText = '';
    _pendingStop = false;
    _feedAudio = false;
    _feedAudioBytes = 0;
  }

  static final RegExp _leadingAsciiLetterOrDigit = RegExp(r'^[A-Za-z0-9]');

  /// 拼接两段识别文本，两段英文之间补一个空格
  static String _join(String text, String sentence) {
    if (text.isNotEmpty && sentence.isNotEmpty) {
      final String last = text[text.length - 1];
      if (last.codeUnitAt(0) < 128 &&
          last.trim().isNotEmpty &&
          _leadingAsciiLetterOrDigit.hasMatch(sentence)) {
        return '$text $sentence';
      }
    }
    return text + sentence;
  }

  // 32 位十六进制随机字符串
  static String _randomId() {
    final math.Random random = math.Random.secure();
    return List<String>.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
