import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'asr_auth.dart';
import 'asr_error.dart';

/// 实时语音识别 WebSocket 客户端
///
/// 连接 asr-api 的 /api/stream，由 asr-api 鉴权后转发给 wf-voice；内网测试时也可以直连 wf-voice。
/// 协议详见 wf-voice 项目的 docs/server-api.md：
/// 1. 连接后发送的第一条文本消息是 clientId；需要边说边出字时，接着发送 partial
/// 2. 二进制消息发送 16kHz、16-bit、单声道 PCM
/// 3. 服务端每识别完一句，推送一条文本消息：[段开始毫秒时间戳+时长秒] 识别文本
/// 4. 发送过 partial 时，说话过程中还会推送正在说的这句的中间结果：[PARTIAL] 识别文本
/// 5. 说话结束时发送 eos，服务端推送完剩余识别结果后回复 [EOS]
///
/// 每次识别使用一个新实例。连接成功之前就可以发送音频，音频先缓存，连接成功后跟在 clientId 后面发送。
/// 调用 [disconnect] 之后不再回调。
class AsrWebSocketClient {
  AsrWebSocketClient({
    required this.onConnected,
    required this.onPartialResult,
    required this.onResult,
    required this.onEos,
    required this.onError,
  });

  /// 连接成功，连接成功之前缓存的音频已经发送
  final VoidCallback onConnected;

  /// 正在说的这句的中间结果，之后会被新的中间结果或这句的最终结果替换
  final ValueChanged<String> onPartialResult;

  /// 识别出一句的最终结果
  final ValueChanged<String> onResult;

  /// eos 之前的识别结果已全部返回
  final VoidCallback onEos;

  /// 连接失败或连接被断开，之后不再回调
  final ValueChanged<AsrError> onError;

  static const String _messageEos = 'eos';
  static const String _messagePartial = 'partial';
  static const String _messageEosAck = '[EOS]';
  static const String _messagePartialPrefix = '[PARTIAL]';
  static const String _messagePong = 'pong';
  static const String _messageTrialPrefix = '[TRIAL]';

  // 发送 eos 前补发约 500ms 静音，让不支持 eos 的旧版本 wf-voice 也能通过 VAD 断句，识别出最后一句。
  // 静音和录音一样按 30ms（960 字节）一条消息发送，单条消息过大时 asr-api 或 wf-voice 会断开连接
  static const int _silenceFrameBytes = 960;
  static const int _silencePaddingFrames = 17;

  // TCP 连接超时
  static const Duration _connectTimeout = Duration(seconds: 5);

  // 握手整体超时，包括 TLS 和等待服务端的 101 响应
  static const Duration _handshakeTimeout = Duration(seconds: 10);
  static const Duration _pingInterval = Duration(seconds: 30);

  WebSocket? _socket;

  // 连接成功之前发送的音频，连接成功后发送
  final List<Uint8List> _pendingAudio = [];
  bool _disconnected = false;

  /// 连接语音识别服务
  ///
  /// [url] 是 asr-api 或 wf-voice 的 WebSocket 地址；[clientId] 是客户端 ID，wf-voice 要求每个连接唯一；
  /// [partialResult] 是否边说边出字；[authCode] 是连接 asr-api 时需要的认证码，直连 wf-voice 时传 null。
  Future<void> connect(String url, String clientId,
      {required bool partialResult, String? authCode}) async {
    debugPrint('正在连接语音识别服务: $url');
    final HttpClient httpClient = HttpClient()
      ..connectionTimeout = _connectTimeout;
    final Future<WebSocket> connecting = WebSocket.connect(
      url,
      // asr-api 从这个 HTTP header 中取认证码
      headers: authCode == null ? null : {AsrAuth.headerAuthCode: authCode},
      customClient: httpClient,
    );
    // 握手结束后释放 HttpClient，升级成功的连接已经脱离 HttpClient
    unawaited(connecting
        .then<void>((_) {}, onError: (Object _) {})
        .whenComplete(httpClient.close));

    final WebSocket socket;
    try {
      socket = await connecting.timeout(_handshakeTimeout);
    } on TimeoutException {
      // 超时之后才建立的连接直接关掉
      unawaited(connecting.then<void>(
          (lateSocket) => lateSocket.close(WebSocketStatus.normalClosure),
          onError: (Object _) {}));
      _fail(const AsrError(AsrErrorKind.connectTimeout));
      return;
    } on WebSocketException catch (e) {
      debugPrint('WebSocket 连接失败: $e');
      _fail(e.httpStatusCode == HttpStatus.unauthorized
          ? const AsrError(AsrErrorKind.unauthorized)
          : AsrError(AsrErrorKind.connectFailed, e.message));
      return;
    } catch (e) {
      debugPrint('WebSocket 连接失败: $e');
      _fail(AsrError(AsrErrorKind.connectFailed, '$e'));
      return;
    }

    if (_disconnected) {
      // 连接期间识别已经结束
      unawaited(socket.close(WebSocketStatus.normalClosure));
      return;
    }
    socket.pingInterval = _pingInterval;
    socket.listen(
      _handleMessage,
      onError: (Object e) {
        debugPrint('WebSocket 连接出错: $e');
        _fail(const AsrError(AsrErrorKind.disconnected));
      },
      onDone: () {
        debugPrint(
            'WebSocket 已关闭: code=${socket.closeCode}, reason=${socket.closeReason}');
        _fail(const AsrError(AsrErrorKind.disconnected));
      },
      cancelOnError: true,
    );

    // 先发送 clientId 等指令，再发送连接成功之前缓存的音频
    socket.add(clientId);
    if (partialResult) {
      socket.add(_messagePartial);
    }
    int pendingBytes = 0;
    for (final Uint8List data in _pendingAudio) {
      socket.add(data);
      pendingBytes += data.length;
    }
    _pendingAudio.clear();
    _socket = socket;
    // 16kHz、16-bit 的音频每毫秒 32 字节
    debugPrint('WebSocket 连接成功，发送连接前缓存的音频 ${pendingBytes ~/ 32}ms');
    onConnected();
  }

  /// 发送音频数据。还没连接成功时先缓存，连接成功后发送
  ///
  /// [pcm] 是 16kHz、16-bit、单声道 PCM，调用之后不能再修改
  void sendAudioData(Uint8List pcm) {
    if (_disconnected) {
      return;
    }
    final WebSocket? socket = _socket;
    if (socket == null) {
      _pendingAudio.add(pcm);
    } else if (socket.readyState == WebSocket.open) {
      // 服务端刚断开、onDone 还没回调时 add 会抛 StateError
      socket.add(pcm);
    }
  }

  /// 通知服务端说话结束，服务端返回剩余识别结果后回调 [onEos]。需要在连接成功后调用
  void sendEos() {
    final WebSocket? socket = _socket;
    if (socket == null ||
        _disconnected ||
        socket.readyState != WebSocket.open) {
      return;
    }
    final Uint8List silence = Uint8List(_silenceFrameBytes);
    for (int i = 0; i < _silencePaddingFrames; i++) {
      socket.add(silence);
    }
    socket.add(_messageEos);
  }

  /// 断开连接，之后不再回调
  void disconnect() {
    _disconnected = true;
    _pendingAudio.clear();
    final WebSocket? socket = _socket;
    _socket = null;
    if (socket != null) {
      unawaited(socket.close(WebSocketStatus.normalClosure));
    }
  }

  void _fail(AsrError error) {
    if (_disconnected) {
      return;
    }
    disconnect();
    onError(error);
  }

  void _handleMessage(dynamic message) {
    if (_disconnected || message is! String) {
      return;
    }
    debugPrint('收到消息: $message');
    if (message == _messageEosAck) {
      onEos();
    } else if (message.startsWith(_messagePartialPrefix)) {
      final String text =
          message.substring(_messagePartialPrefix.length).trim();
      if (text.isNotEmpty) {
        onPartialResult(text);
      }
    } else if (message.startsWith(_messageTrialPrefix)) {
      // 体验版每个连接只识别前 30 秒音频
      debugPrint(message);
    } else if (message != _messagePong) {
      final String text = _parseResultText(message);
      if (text.isNotEmpty) {
        onResult(text);
      }
    }
  }

  /// 去掉识别结果的时间前缀，例如 "[1740992313000+2.35] 你好，世界，" 返回 "你好，世界，"
  static String _parseResultText(String message) {
    if (message.startsWith('[')) {
      final int end = message.indexOf(']');
      if (end > 0) {
        message = message.substring(end + 1);
      }
    }
    return message.trim();
  }
}
