import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:rtckit/rtckit_method_channel.dart';


//CallSession状态
const int kWFAVEngineStateIdle = 0;
const int kWFAVEngineStateOutgoing = 1;
const int kWFAVEngineStateIncoming = 2;
const int kWFAVEngineStateConnecting = 3;
const int kWFAVEngineStateConnected = 4;

//通话结束原因
///未知错误
const int kWFAVCallEndReasonUnknown = 0;
///忙线
const int kWFAVCallEndReasonBusy = 1;
///链路错误
const int kWFAVCallEndReasonSignalError = 2;
///用户挂断
const int kWFAVCallEndReasonHangup = 3;
///媒体错误
const int kWFAVCallEndReasonMediaError = 4;
///对方挂断
const int kWFAVCallEndReasonRemoteHangup = 5;
///摄像头错误
const int kWFAVCallEndReasonOpenCameraFailure = 6;
///未接听
const int kWFAVCallEndReasonTimeout = 7;
///被其它端接听
const int kWFAVCallEndReasonAcceptByOtherClient = 8;
///所有人都离开
const int kWFAVCallEndReasonAllLeft = 9;
///对方忙线中
const int kWFAVCallEndReasonRemoteBusy = 10;
///对方未接听
const int kWFAVCallEndReasonRemoteTimeout = 11;
///对方网络错误
const int kWFAVCallEndReasonRemoteNetworkError = 12;
///通话/会议被销毁
const int kWFAVCallEndReasonRoomDestroyed = 13;
///通话/会议不存在
const int kWFAVCallEndReasonRoomNotExist = 14;
///通话/会议人数已满
const int kWFAVCallEndReasonRoomParticipantsFull = 15;
///被其他事件打断
const int kWFAVCallEndReasonInterrupted = 16;
///对方被其他事件打断
const int kWFAVCallEndReasonRemoteInterrupted = 17;

//摄像头位置
const int kWFAVCameraPositionUnknown = 0;
const int kWFAVCameraPositionFront = 1;
const int kWFAVCameraPositionBack = 2;

//视频属性  分辨率(宽x高), 帧率(fps),码率(kbps)。超过720P还需要看设备支持不支持。
/// kWFAVVideoProfile120P:       160x120,    15, 120
const int kWFAVVideoProfile120P       = 0 ;
/// kWFAVVideoProfile120P_3:     120x120,    15, 100
const int kWFAVVideoProfile120P_3     = 2 ;
/// kWFAVVideoProfile180P:       320x180,    15, 280
const int kWFAVVideoProfile180P       = 10;
/// kWFAVVideoProfile180P_3:     180x180,    15, 200
const int kWFAVVideoProfile180P_3     = 12;
/// kWFAVVideoProfile180P_4:     240x180,    15, 240
const int kWFAVVideoProfile180P_4     = 13;
/// kWFAVVideoProfile240P:       320x240,    15, 360
const int kWFAVVideoProfile240P       = 20;
/// kWFAVVideoProfile240P_3:     240x240,    15, 280
const int kWFAVVideoProfile240P_3     = 22;
/// kWFAVVideoProfile240P_4:     424x240,    15, 400
const int kWFAVVideoProfile240P_4     = 23;
/// kWFAVVideoProfile360P:       640x360,    15, 800
const int kWFAVVideoProfile360P       = 30;
/// kWFAVVideoProfile360P_3:     360x360,    15, 520
const int kWFAVVideoProfile360P_3     = 32;
/// kWFAVVideoProfile360P_4:     640x360,    30, 1200
const int kWFAVVideoProfile360P_4     = 33;
/// kWFAVVideoProfile360P_6:     360x360,    30, 780
const int kWFAVVideoProfile360P_6     = 35;
/// kWFAVVideoProfile360P_7:     480x360,    15, 1000
const int kWFAVVideoProfile360P_7     = 36;
/// kWFAVVideoProfile360P_8:     480x360,    30, 1500
const int kWFAVVideoProfile360P_8     = 37;
/// kWFAVVideoProfile480P:       640x480,    15, 1000
const int kWFAVVideoProfile480P       = 40;
/// kWFAVVideoProfile480P_3:     480x480,    15, 800
const int kWFAVVideoProfile480P_3     = 42;
/// kWFAVVideoProfile480P_4:     640x480,    30, 1500
const int kWFAVVideoProfile480P_4     = 43;
/// kWFAVVideoProfile480P_6:     480x480,    30, 1200
const int kWFAVVideoProfile480P_6     = 45;
/// kWFAVVideoProfile480P_8:     848x480,    15, 1200
const int kWFAVVideoProfile480P_8     = 47;
/// kWFAVVideoProfile480P_9:     848x480,    30, 1800
const int kWFAVVideoProfile480P_9     = 48;
/// kWFAVVideoProfile720P:       1280x720,   15, 2400
const int kWFAVVideoProfile720P       = 50;
/// kWFAVVideoProfile720P_3:     1280x720,   30, 3699
const int kWFAVVideoProfile720P_3     = 52;
/// kWFAVVideoProfile720P_5:     960x720,    15, 1920
const int kWFAVVideoProfile720P_5     = 54;
/// kWFAVVideoProfile720P_6:     960x720,    30, 2880
const int kWFAVVideoProfile720P_6     = 55;
/// kWFAVVideoProfile1080P: 1920x1080, 15, 4160
const int kWFAVVideoProfile1080P      = 56;
/// kWFAVVideoProfile1080P_3: 1920x1080, 30, 6240
const int kWFAVVideoProfile1080P_3    = 57;
/// kWFAVVideoProfile2K: 2540x1440, 15, 6240
const int kWFAVVideoProfile2K         = 58;
/// kWFAVVideoProfile2K_3: 2540x1440, 30, 8320
const int kWFAVVideoProfile2K_3       = 59;
/// kWFAVVideoProfile4K: 3840x2160, 15, 12480
const int kWFAVVideoProfile4K         = 60;
/// kWFAVVideoProfile4K_3: 3840x2160, 30, 18720
const int kWFAVVideoProfile4K_3       = 61;
const int kWFAVVideoProfileDefault    = kWFAVVideoProfile360P;


const int kWFAVVideoTypeNone = 0;
const int kWFAVVideoTypeBigStream = 1;
const int kWFAVVideoTypeSmallStream = 2;


class ParticipantProfile {
  final String userId;
  final int startTime;
  final int state;
  final bool videoMuted;
  final bool audioMuted;
  final bool audience;
  final bool screenSharing;

  ParticipantProfile(this.userId, this.startTime, this.state, this.videoMuted,
      this.audioMuted, this.audience, this.screenSharing);
}

class CallSession implements CallSessionCallback {
  String callId;
  late int state;
  String? inviter;
  late bool audioOnly;
  int? endReason;
  Conversation? conversation;
  late bool speaker;
  late bool videoMuted;
  late bool audioMuted;
  late bool multiCall;
  late bool audience;
  int? endTime;
  late bool conference;
  late bool advanced;
  String? initiator;
  int? connectedTime;
  late int startTime;

  CallSessionCallback? _callback;

  CallSession(this.callId);

  void setCallSessionCallback(CallSessionCallback? callback) {
    _callback = callback;
    Rtckit._setCallSessionCallback(callId, this);
  }

  void setLocalVideoView(int viewId) async {
    return Rtckit._setLocalVideoView(callId, viewId);
  }

  void setRemoteVideoView(String userId, bool screenSharing, int viewId) async {
    return Rtckit._setRemoteVideoView(callId, userId, screenSharing, viewId);
  }

  void startPreview() {
    Rtckit._startPreview(callId);
  }

  Future<List<String>> get participantIds async {
    return Rtckit._getParticipantIds(callId);
  }

  Future<List<ParticipantProfile>> get participantProfiles async {
    return Rtckit._getParticipantProfiles(callId);
  }

  Future<void> answerCall(bool audioOnly) async {
    this.audioOnly = this.audioOnly || audioOnly;
    return Rtckit._answerCall(callId, audioOnly);
  }

  Future<void> changeToAudioOnly() async {
    if(!audioOnly && state == kWFAVEngineStateConnected) {
      audioOnly = true;
      return Rtckit._changeToAudioOnly(callId);
    }
    return;
  }

  Future<void> endCall() async {
    return Rtckit._endCall(callId);
  }

  Future<void> muteAudio(bool muted) async {
    audioMuted = muted;
    return Rtckit._muteAudio(callId, muted);
  }

  Future<void> enableSpeaker(bool speaker) async {
    this.speaker = speaker;
    return Rtckit._enableSpeaker(callId, speaker);
  }

  Future<void> muteVideo(bool muted) async {
    videoMuted = muted;
    return Rtckit._muteVideo(callId, muted);
  }

  Future<void> switchCamera() async {
    return Rtckit._switchCamera(callId);
  }

  Future<int> get cameraPosition async {
    return Rtckit._getCameraPosition(callId);
  }

  Future<bool> get isBluetoothSpeaker async {
    return Rtckit._isBluetoothSpeaker(callId);
  }

  Future<bool> get isHeadsetPluggedIn async {
    return Rtckit._isHeadsetPluggedIn(callId);
  }

  void _syncData(CallSession session) {
    state = session.state;
    inviter = session.inviter;
    audioOnly = session.audioOnly;
    endReason = session.endReason;
    speaker = session.speaker;
    videoMuted = session.videoMuted;
    audioMuted = session.audioMuted;
    audience = session.audience;
    endTime = session.endTime;
    initiator = session.initiator;
    connectedTime = session.connectedTime;
    startTime = session.startTime;
  }

  @override
  void didCallEndWithReason(CallSession session, int reason) {
    _syncData(session);
    endReason = reason;
    if(_callback != null) {
      _callback!.didCallEndWithReason(this, reason);
    }
  }

  @override
  void didChangeInitiator(CallSession session, String initiator) {
    _syncData(session);
    this.initiator = initiator;
    if(_callback != null) {
      _callback!.didChangeInitiator(this, initiator);
    }
  }

  @override
  void didChangeMode(CallSession session, bool isAudioOnly) {
    _syncData(session);
    audioOnly = isAudioOnly;
    if(_callback != null) {
      _callback!.didChangeMode(this, isAudioOnly);
    }
  }

  @override
  void didChangeState(CallSession session, int state) {
    _syncData(session);
    this.state = state;
    if (_callback != null) {
      _callback!.didChangeState(this, state);
    }
  }

  @override
  void didCreateLocalVideoTrack(CallSession session) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didCreateLocalVideoTrack(this);
    }
  }

  @override
  void didError(CallSession session, String error) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didError(this, error);
    }
  }

  @override
  void didGetStats(CallSession session) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didGetStats(this);
    }
  }

  @override
  void didParticipantConnected(CallSession session, String userId, bool screenSharing) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didParticipantConnected(this, userId, screenSharing);
    }
  }

  @override
  void didParticipantJoined(CallSession session, String userId, bool screenSharing) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didParticipantJoined(this, userId, screenSharing);
    }
  }

  @override
  void didParticipantLeft(CallSession session, String userId, bool screenSharing, int reason) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didParticipantLeft(this, userId, screenSharing, reason);
    }
  }

  @override
  void didReceiveRemoteVideoTrack(CallSession session, String userId, bool screenSharing) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didReceiveRemoteVideoTrack(this, userId, screenSharing);
    }
  }

  @override
  void didVideoMuted(CallSession session, String userId, bool videoMuted) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didVideoMuted(this, userId, videoMuted);
    }
  }

  @override
  void didChangeAudioRoute(CallSession session) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didChangeAudioRoute(this);
    }
  }

  @override
  void didChangeType(CallSession session, String userId, bool audience) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didChangeType(this, userId, audience);
    }
  }

  @override
  void didMuteStateChanged(CallSession session, List<String> userIds) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didMuteStateChanged(this, userIds);
    }
  }

  @override
  void didRemoteMediaLost(CallSession session, String userId, String media, bool uplink, int lostPackage, bool screenSharing) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didRemoteMediaLost(this, userId, media, uplink, lostPackage, screenSharing);
    }
  }

  @override
  void didReportAudioVolume(CallSession session, String userId, int volume) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didReportAudioVolume(this, userId, volume);
    }
  }

  @override
  void didMediaLost(CallSession session, String media, int lostPackage, bool screenSharing) {
    _syncData(session);
    if(_callback != null) {
      _callback!.didMediaLost(this, media, lostPackage, screenSharing);
    }
  }
}

abstract class CallSessionCallback {
  void didCallEndWithReason(CallSession session, int reason) {}
  void didChangeInitiator(CallSession session, String initiator) {}
  void didChangeMode(CallSession session, bool isAudioOnly) {}
  void didChangeState(CallSession session, int state) {}
  void didCreateLocalVideoTrack(CallSession session) {}
  void didError(CallSession session, String error) {}
  void didGetStats(CallSession session) {}
  void didParticipantConnected(CallSession session, String userId, bool screenSharing) {}
  void didParticipantJoined(CallSession session, String userId, bool screenSharing) {}
  void didParticipantLeft(CallSession session, String userId, bool screenSharing, int reason) {}
  void didReceiveRemoteVideoTrack(CallSession session, String userId, bool screenSharing) {}
  void didVideoMuted(CallSession session, String userId, bool videoMuted) {}

  void didReportAudioVolume(CallSession session, String userId, int volume) {}
  void didChangeType(CallSession session, String userId, bool audience) {}
  void didChangeAudioRoute(CallSession session) {}
  void didMuteStateChanged(CallSession session, List<String> userIds);
  void didMediaLost(CallSession session, String media, int lostPackage, bool screenSharing) {}
  void didRemoteMediaLost(CallSession session, String userId, String media, bool uplink, int lostPackage, bool screenSharing) {}
}

typedef DidReceiveCallCallback = void Function(CallSession callSession);
typedef ShouldStartRingCallback = void Function(bool incomming);
typedef ShouldStopRingCallback = void Function();
typedef DidEndCallCallback = void Function(int reason, int duration);

class Rtckit {
  static String defaultUserPortrait = 'assets/images/user_avatar_default.png';

  static void init({DidReceiveCallCallback? didReceiveCallCallback, ShouldStartRingCallback? shouldStartRingCallback, ShouldStopRingCallback? shouldStopRingCallback, DidEndCallCallback? didEndCallCallback}) {
    RtckitPlatform.instance.initProto(didReceiveCallCallback, shouldStartRingCallback, shouldStopRingCallback, didEndCallCallback);
  }

  static Future<int> get maxVideoCallCount async {
    return RtckitPlatform.instance.maxVideoCallCount;
  }

  static Future<int> get maxAudioCallCount async {
    return RtckitPlatform.instance.maxAudioCallCount;
  }

  static Future<void> seMaxVideoCallCount(int count) async {
    return RtckitPlatform.instance.seMaxVideoCallCount(count);
  }

  static Future<void> seMaxAudioCallCount(int count) async {
    return RtckitPlatform.instance.seMaxAudioCallCount(count);
  }

  static Future<void> addICEServer(String url, String name, String password) async {
    return RtckitPlatform.instance.addICEServer(url, name, password);
  }

  static Future<CallSession?> startSingleCall(String userId, bool audioOnly) async {
      return RtckitPlatform.instance.startSingleCall(userId, audioOnly);
  }

  static Future<CallSession?> startMultiCall(String groupId, List<String> participants, bool audioOnly) async {
    return RtckitPlatform.instance.startMultiCall(groupId, participants, audioOnly);
  }

  static Future<bool> isSupportMultiCall() async {
    return RtckitPlatform.instance.isSupportMultiCall();
  }

  static Future<bool> isSupportConference() async {
    return RtckitPlatform.instance.isSupportConference();
  }
/*
视频属性 (Profile) 定义
视频属性	枚举值	分辨率（宽x高）	帧率（fps）	码率（kbps）
120P	0	160x120	15	120
120P_3	2	120x120	15	100
180P	10	320x180	15	280
180P_3	12	180x180	15	200
180P_4	13	240x180	15	240
240P	20	320x240	15	360
240P_3	22	240x240	15	280
240P_4	24	424x240	15	400
360P	30	640x360	15	800
360P_3	32	360x360	15	520
360P_4	33	640x360	30	1200
360P_6	35	360x360	30	780
360P_7	36	480x360	15	1000
360P_8	37	480x360	30	1500
480P	40	640x480	15	1000
480P_3	42	480x480	15	800
480P_4	43	640x480	30	1500
480P_6	45	480x480	30	1200
480P_8	47	848x480	15	1200
480P_9	48	848x480	30	1800
720P	50	1280x720 15	2400
720P_3	52	1280x720 30	3699
720P_5	54	960x720  15 1920
720P_6	55	960x720  30	2880
1080P 60	1920×1080  15	4200
1080P_3 60	1920×1080  30	6300
1080P_5 60	1920×1080  60	9560
 */
  static Future<void> setVideoProfile(int profile, {bool swapWidthHeight = false}) async {
    return RtckitPlatform.instance.setVideoProfile(profile, swapWidthHeight);
  }

  static Future<CallSession?> currentCallSession() async {
    return RtckitPlatform.instance.currentCallSession();
  }

  static Future<void> _setLocalVideoView(String callId, int viewId) async {
    return RtckitPlatform.instance.setLocalVideoView(callId, viewId);
  }

  static Future<void> _setRemoteVideoView(String callId, String userId, bool screenSharing, int viewId) async {
    return RtckitPlatform.instance.setRemoteVideoView(callId, userId, screenSharing, viewId);
  }

  static Future<void> _startPreview(String callId) async {
    return RtckitPlatform.instance.startPreview(callId);
  }

  static Future<void> _answerCall(String callId, bool audioOnly) async {
    return RtckitPlatform.instance.answerCall(callId, audioOnly);
  }

  static Future<void> _changeToAudioOnly(String callId) async {
    return RtckitPlatform.instance.changeToAudioOnly(callId);
  }

  static Future<void> _endCall(String callId) async {
    return RtckitPlatform.instance.endCall(callId);
  }

  static Future<void> _muteAudio(String callId, bool muted) async {
    return RtckitPlatform.instance.muteAudio(callId, muted);
  }

  static Future<void> _enableSpeaker(String callId, bool speaker) async {
    return RtckitPlatform.instance.enableSpeaker(callId, speaker);
  }

  static Future<void> _muteVideo(String callId, bool muted) async {
    return RtckitPlatform.instance.muteVideo(callId, muted);
  }

  static Future<void> _switchCamera(String callId) async {
    return RtckitPlatform.instance.switchCamera(callId);
  }

  static Future<int> _getCameraPosition(String callId) async {
    return RtckitPlatform.instance.getCameraPosition(callId);
  }

  static Future<bool> _isBluetoothSpeaker(String callId) async {
    return RtckitPlatform.instance.isBluetoothSpeaker(callId);
  }

  static Future<bool> _isHeadsetPluggedIn(String callId) async {
    return RtckitPlatform.instance.isHeadsetPluggedIn(callId);
  }

  static Future<List<String>> _getParticipantIds(String callId) async {
    return RtckitPlatform.instance.getParticipantIds(callId);
  }

  static Future<List<ParticipantProfile>> _getParticipantProfiles(String callId) async {
    return RtckitPlatform.instance.getParticipantProfiles(callId);
  }

  static void _setCallSessionCallback(String callId, CallSessionCallback? callback) {
    RtckitPlatform.instance.setCallSessionCallback(callId, callback);
  }
}
