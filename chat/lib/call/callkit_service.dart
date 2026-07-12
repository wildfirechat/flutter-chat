import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:avenginekit/engine/avenginekit.dart';
import 'package:avenginekit/engine/call_session.dart';
import 'package:avenginekit/engine/call_state.dart';
import 'package:imclient/imclient.dart';

/// 桥接 iOS CallKit 与 Flutter 音视频引擎。
///
/// iOS 端在收到 PushKit VoIP 推送后，会先调起系统 CallKit 来电界面；
/// 用户点击接听/挂断后，原生通过 MethodChannel 通知到这里，再驱动
/// [avEngineKit] 进行实际的接听或挂断。
class CallKitService {
  static const MethodChannel _channel = MethodChannel('chat.wildfire/callkit');
  static final CallKitService instance = CallKitService._internal();

  String? _pendingAnswerCallId;
  bool _initialized = false;

  CallKitService._internal();

  void init() {
    if (_initialized || !Platform.isIOS) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'didUpdateVoipToken':
        final token = call.arguments['token'] as String?;
        if (token != null && token.isNotEmpty) {
          Imclient.setVoipDeviceToken(token);
        }
        break;
      case 'didReceiveIncomingPush':
        final callId = call.arguments['callId'] as String?;
        if (callId != null && callId.isNotEmpty) {
          _pendingAnswerCallId = callId;
        }
        break;
      case 'performAnswerCall':
        final callId = call.arguments['callId'] as String?;
        if (callId != null && callId.isNotEmpty) {
          _performAnswerCall(callId);
        }
        break;
      case 'performEndCall':
        final callId = call.arguments['callId'] as String?;
        if (callId != null && callId.isNotEmpty) {
          _performEndCall(callId);
        }
        break;
      case 'didChangeCallMute':
        final callId = call.arguments['callId'] as String?;
        final muted = call.arguments['muted'] as bool? ?? false;
        if (callId != null && callId.isNotEmpty) {
          _performMuteCall(callId, muted);
        }
        break;
    }
  }

  void _performAnswerCall(String callId) {
    _pendingAnswerCallId = callId;
    final session = avEngineKit.currentSession;
    if (session != null &&
        session.callId == callId &&
        session.status == CallState.STATUS_INCOMING) {
      session.answerCall(false);
      _pendingAnswerCallId = null;
      _reportCallConnected(callId);
    }
    // 如果 session 尚未建立（应用从 killed 状态被 PushKit 唤醒），
    // 则等待 [onReceiveCall] 中匹配到同一 callId 后再自动接听。
  }

  void _performEndCall(String callId) {
    _pendingAnswerCallId = null;
    final session = avEngineKit.currentSession;
    if (session != null && session.callId == callId) {
      session.hangup();
    }
    _reportCallEnded(callId);
  }

  void _performMuteCall(String callId, bool muted) {
    final session = avEngineKit.currentSession;
    if (session != null && session.callId == callId) {
      session.muteAudio(muted);
    }
  }

  /// 当 [avenginekit] 收到来电时调用。如果存在通过 CallKit 触发的待接听请求，
  /// 且 callId 匹配，则自动接听。
  void onReceiveCall(CallSession session) {
    if (_pendingAnswerCallId != null &&
        _pendingAnswerCallId == session.callId &&
        session.status == CallState.STATUS_INCOMING) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (session.status == CallState.STATUS_INCOMING) {
          session.answerCall(false);
          _reportCallConnected(session.callId);
        }
      });
      _pendingAnswerCallId = null;
    }
  }

  /// 通知原生 CallKit 通话已接通。
  void reportCallConnected(String callId) {
    if (!Platform.isIOS) return;
    _reportCallConnected(callId);
  }

  /// 通知原生 CallKit 通话已结束。
  void reportCallEnded(String callId) {
    if (!Platform.isIOS) return;
    _reportCallEnded(callId);
  }

  void _reportCallConnected(String callId) {
    _channel.invokeMethod('reportCallConnected', {'callId': callId});
  }

  void _reportCallEnded(String callId) {
    _channel.invokeMethod('reportCallEnded', {'callId': callId});
  }
}
