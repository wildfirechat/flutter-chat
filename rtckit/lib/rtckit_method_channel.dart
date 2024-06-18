import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imclient/model/conversation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:rtckit/rtckit.dart';


/// An implementation of [RtckitPlatform] that uses method channels.
class RtckitPlatform extends PlatformInterface {
  /// Constructs a RtckitPlatform.
  RtckitPlatform() : super(token: _token);

  static final Object _token = Object();

  static RtckitPlatform _instance = RtckitPlatform();

  /// The default instance of [RtckitPlatform] to use.
  ///
  /// Defaults to [RtckitPlatform].
  static RtckitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RtckitPlatform] when
  /// they register themselves.
  static set instance(RtckitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('rtckit');

  static DidReceiveCallCallback? _didReceiveCallCallback;
  static ShowCallViewCallback? _showCallViewCallback;
  static ShouldStartRingCallback? _shouldStartRingCallback;
  static ShouldStopRingCallback? _shouldStopRingCallback;
  static DidEndCallCallback? _didEndCallCallback;
  static final Map<String, CallSessionCallback> _callSessionCallbacks = {};

  static int _maxAudioCallCount = 9;
  static int _maxVideoCallCount = 4;

  Future<void> initProto(DidReceiveCallCallback? didReceiveCallCallback, ShowCallViewCallback? showCallViewCallback, ShouldStartRingCallback? shouldStartRingCallback, ShouldStopRingCallback? shouldStopRingCallback, DidEndCallCallback? didEndCallCallback) async {
    _didReceiveCallCallback = didReceiveCallCallback;
    _showCallViewCallback = showCallViewCallback;
    _shouldStartRingCallback = shouldStartRingCallback;
    _shouldStopRingCallback = shouldStopRingCallback;
    _didEndCallCallback = didEndCallCallback;

    methodChannel.invokeMethod<String>('initProto');
    methodChannel.invokeMethod("getMaxAudioCallCount").then((value) => _maxAudioCallCount = value);
    methodChannel.invokeMethod("getMaxVideoCallCount").then((value) => _maxVideoCallCount = value);

    methodChannel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'didReceiveCallCallback':
          if(_didReceiveCallCallback != null) {
            Map<dynamic, dynamic> args = call.arguments;
            Map<dynamic, dynamic> mapSession = args['callSession'];
            CallSession? session = sessionFromMap(mapSession);
            if(session != null) {
              _didReceiveCallCallback!(session!);
            }
          }
          break;
        case 'showCallView':
          if(_showCallViewCallback != null) {
            Map<dynamic, dynamic> args = call.arguments;
            Map<dynamic, dynamic> mapSession = args['callSession'];
            CallSession? session = sessionFromMap(mapSession);
            if(session != null) {
              _showCallViewCallback!(session!);
            }
          }
          break;
        case 'shouldStartRingCallback':
          if(_shouldStartRingCallback != null) {
            Map<dynamic, dynamic> args = call.arguments;
            bool incoming = args['incoming'];
            _shouldStartRingCallback!(incoming);
          }
          break;
        case 'shouldStopRingCallback':
          if(_shouldStopRingCallback != null) {
            _shouldStopRingCallback!();
          }
          break;
        case 'didEndCallCallback':
          if(_didEndCallCallback != null) {
            Map<dynamic, dynamic> args = call.arguments;
            int reason = args['reason'];
            int duration = args['duration'];
            _didEndCallCallback!(reason, duration);
          }
          break;

        //Call session callback
        case 'didCallEndWithReason':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          int reason = args['reason'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didCallEndWithReason(sessionFromMap(args['session'])!, reason);
          }
          break;
        case 'didChangeInitiator':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            CallSession session = sessionFromMap(args['session'])!;
            callback.didChangeInitiator(session, session.inviter);
          }
          break;
        case 'didChangeMode':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          bool isAudioOnly = args['isAudioOnly'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didChangeMode(sessionFromMap(args['session'])!, isAudioOnly);
          }
          break;
        case 'didChangeState':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          int state = args['state'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didChangeState(sessionFromMap(args['session'])!, state);
          }
          break;
        case 'didCreateLocalVideoTrack':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didCreateLocalVideoTrack(sessionFromMap(args['session'])!);
          }
          break;
        case 'didError':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          String error = args['error'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didError(sessionFromMap(args['session'])!, error);
          }
          break;
        case 'didGetStats':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didGetStats(sessionFromMap(args['session'])!);
          }
          break;
        case 'didParticipantConnected':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          String userId = args['userId'];
          bool screenSharing = args['screenSharing'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didParticipantConnected(sessionFromMap(args['session'])!, userId, screenSharing);
          }
          break;
        case 'didParticipantJoined':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          String userId = args['userId'];
          bool screenSharing = args['screenSharing'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didParticipantJoined(sessionFromMap(args['session'])!, userId, screenSharing);
          }
          break;
        case 'didParticipantLeft':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          String userId = args['userId'];
          bool screenSharing = args['screenSharing'];
          int reason = args['reason'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didParticipantLeft(sessionFromMap(args['session'])!, userId, screenSharing, reason);
          }
          break;
        case 'didReceiveRemoteVideoTrack':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          String userId = args['userId'];
          bool screenSharing = args['screenSharing'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didReceiveRemoteVideoTrack(sessionFromMap(args['session'])!, userId, screenSharing);
          }
          break;
        case 'didVideoMuted':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          String userId = args['userId'];
          bool videoMuted = args['videoMuted'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didVideoMuted(sessionFromMap(args['session'])!, userId, videoMuted);
          }
          break;
        case 'didReportAudioVolume':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          String userId = args['userId'];
          int volume = args['volume'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didReportAudioVolume(sessionFromMap(args['session'])!, userId, volume);
          }
          break;
        case 'didChangeType':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          String userId = args['userId'];
          bool audience = args['audience'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didChangeType(sessionFromMap(args['session'])!, userId, audience);
          }
          break;
        case 'didChangeAudioRoute':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didChangeAudioRoute(sessionFromMap(args['session'])!);
          }
          break;
        case 'didMuteStateChanged':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          List<String> userIds = args['userIds'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didMuteStateChanged(sessionFromMap(args['session'])!, userIds);
          }
          break;
        case 'didMediaLost':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          String media = args['media'];
          int lostPackage = args['lostPackage'];
          bool screenSharing = args['screenSharing'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didMediaLost(sessionFromMap(args['session'])!, media, lostPackage, screenSharing);
          }
          break;
        case 'didRemoteMediaLost':
          Map<dynamic, dynamic> args = call.arguments;
          String callId = args['callId'];
          String userId = args['userId'];
          String media = args['media'];
          bool uplink = args['uplink'];
          int lostPackage = args['lostPackage'];
          bool screenSharing = args['screenSharing'];
          CallSessionCallback? callback = _callSessionCallbacks[callId];
          if(callback != null) {
            callback.didRemoteMediaLost(sessionFromMap(args['session'])!, userId, media, uplink, lostPackage, screenSharing);
          }
          break;
        default:
          debugPrint("Unknown event '${call.method}'");
          break;
      }
    });
  }

  int get maxVideoCallCount {
    return _maxVideoCallCount;
  }

  int get maxAudioCallCount {
    return _maxAudioCallCount;
  }

  Future<void> seMaxVideoCallCount(int count) async {
    _maxVideoCallCount = count;
    return await methodChannel.invokeMethod("seMaxVideoCallCount", {'count':count});
  }

  Future<void> seMaxAudioCallCount(int count) async {
    _maxAudioCallCount = count;
    return await methodChannel.invokeMethod("seMaxAudioCallCount", {'count':count});
  }

  Future<void> enableCallkit() async {
    return await methodChannel.invokeMethod("enableCallkit");
  }

  Future<void> addICEServer(String url, String name, String password) async {
    var args = {"url": url, "name": name, "password": password};
    return await methodChannel.invokeMethod("addICEServer", args);
  }

  Future<CallSession?> startSingleCall(String userId, bool audioOnly) async {
    var args = {"userId": userId, "audioOnly": audioOnly};
    Map<dynamic, dynamic> map = await methodChannel.invokeMethod("startSingleCall", args);
    return sessionFromMap(map);
  }

  Future<CallSession?> startMultiCall(String groupId, List<String> participants, bool audioOnly) async {
    var args = {"groupId": groupId, "participants": participants, "audioOnly": audioOnly};
    Map<dynamic, dynamic> map = await methodChannel.invokeMethod("startMultiCall", args);
    return sessionFromMap(map);
  }

  Future<bool> isSupportMultiCall() async {
    return await methodChannel.invokeMethod("isSupportMultiCall");
  }

  Future<bool> isSupportConference() async {
    return await methodChannel.invokeMethod("isSupportConference");
  }

  Future<void> setVideoProfile(int profile, bool swapWidthHeight) async {
    return await methodChannel.invokeMethod("setVideoProfile", {'profile':profile, 'swapWidthHeight':swapWidthHeight});
  }

  Future<CallSession?> currentCallSession() async {
    Map<dynamic, dynamic>? map = await methodChannel.invokeMethod('currentCallSession');
    return sessionFromMap(map);
  }

  CallSession? sessionFromMap(Map<dynamic, dynamic>? map) {
    if(map == null) {
      return null;
    }
    CallSession session = CallSession(map["callId"]);
    session.connectedTime = map['connectedTime'];
    session.state = map['state'];
    session.inviter = map['inviter'];
    session.audioOnly = map['audioOnly'];
    session.endReason = map['endReason'];
    session.conversation = _convertProtoConversation(map['conversation']);
    session.multiCall = map['multiCall'];
    session.audience = map['audience'];
    session.endTime = map['endTime'];
    session.conference = map['conference'];
    session.advanced = map['advanced'];
    session.initiator = map['initiator'];
    session.startTime = map['startTime'];
    session.speaker = map['speaker'];
    session.audioMuted = map['audioMuted'];
    session.videoMuted = map['videoMuted'];
    return session;
  }

  void setCallSessionCallback(String callId, CallSessionCallback? callback) {
    if(callback != null) {
      _callSessionCallbacks[callId] = callback;
    } else {
      _callSessionCallbacks.remove(callId);
    }
  }

  Future<void> setLocalVideoView(String callId, int viewId) async {
    return await methodChannel.invokeMethod("setLocalVideoView", {'callId':callId, "viewId":viewId});
  }

  Future<void> setRemoteVideoView(String callId, String userId, bool screenSharing, int viewId) async {
    return await methodChannel.invokeMethod("setRemoteVideoView", {'callId':callId, 'userId':userId, 'screenSharing':screenSharing, "viewId":viewId});
  }

  Future<void> startPreview(String callId) async {
    return await methodChannel.invokeMethod("startPreview", {'callId':callId});
  }

  Future<void> answerCall(String callId, bool audioOnly) async {
    return await methodChannel.invokeMethod("answerCall", {'callId':callId, 'audioOnly':audioOnly});
  }

  Future<void> changeToAudioOnly(String callId) async {
    return await methodChannel.invokeMethod("changeToAudioOnly", {'callId':callId});
  }

  Future<void> endCall(String callId) async {
    return await methodChannel.invokeMethod("endCall", {'callId':callId});
  }

  Future<void> muteAudio(String callId, bool muted) async {
    return await methodChannel.invokeMethod("muteAudio", {'callId':callId, 'muted':muted});
  }

  Future<void> enableSpeaker(String callId, bool speaker) async {
    return await methodChannel.invokeMethod("enableSpeaker", {'callId':callId, 'speaker':speaker});
  }

  Future<void> muteVideo(String callId, bool muted) async {
    return await methodChannel.invokeMethod("muteVideo", {'callId':callId, 'muted':muted});
  }

  Future<void> switchCamera(String callId) async {
    return await methodChannel.invokeMethod("switchCamera", {'callId':callId});
  }

  Future<int> getCameraPosition(String callId) async {
    return await methodChannel.invokeMethod("getCameraPosition", {'callId':callId});
  }

  Future<bool> isBluetoothSpeaker(String callId) async {
    return await methodChannel.invokeMethod("isBluetoothSpeaker", {'callId':callId});
  }

  Future<bool> isHeadsetPluggedIn(String callId) async {
    return await methodChannel.invokeMethod("isHeadsetPluggedIn", {'callId':callId});
  }

  Future<void> inviteNewParticipants(String callId, List<String> participants) async {
    return await methodChannel.invokeMethod("inviteNewParticipants", {'callId':callId, 'participants':participants});
  }

  Future<List<String>> getParticipantIds(String callId) async {
    List<Object?> list = await methodChannel.invokeMethod("getParticipantIds", {'callId':callId});
    List<String> result = [];
    for (var value in list) {
      if(value is String) {
        result.add(value);
      }
    }
    return result;
  }

  Future<List<ParticipantProfile>> getParticipantProfiles(String callId) async {
    List<dynamic> mapList = await methodChannel.invokeMethod("getParticipantProfiles", {'callId':callId});
    return _convertProtoParticipantProfiles(mapList);
  }

  Future<List<ParticipantProfile>> getAllProfiles(String callId) async {
    List<dynamic> mapList = await methodChannel.invokeMethod("getAllProfiles", {'callId':callId});
    return _convertProtoParticipantProfiles(mapList);
  }

  Future<ParticipantProfile> getMyProfiles(String callId) async {
    dynamic map = await methodChannel.invokeMethod("getMyProfiles", {'callId':callId});
    return _convertProtoParticipantProfile(map);
  }

  List<ParticipantProfile> _convertProtoParticipantProfiles(List<dynamic> mapList) {
    List<ParticipantProfile> pps = [];
    for (var value in mapList) {
      pps.add(_convertProtoParticipantProfile(value));
    }
    return pps;
  }

  ParticipantProfile _convertProtoParticipantProfile(dynamic map) {
    Map m = map;
    return ParticipantProfile(m["userId"], m["startTime"], m["state"], m["videoMuted"],
        m["audioMuted"], m["audience"], m["screenSharing"]);
  }

  Conversation? _convertProtoConversation(Map<dynamic, dynamic>? map) {
    if(map == null) {
      return null;
    }

    Conversation conversation = Conversation();
    conversation.conversationType = ConversationType.values[map['type']];
    conversation.target = map['target'];
    if (map['line'] == null) {
      conversation.line = 0;
    } else {
      conversation.line = map['line'];
    }

    return conversation;
  }
}
