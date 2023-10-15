import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  Future<void> initProto() async {
    methodChannel.invokeMethod<String>('initProto');
  }

  Future<int> get maxVideoCallCount async {
    return await methodChannel.invokeMethod("maxVideoCallCount");
  }

  Future<int> get maxAudioCallCount async {
    return await methodChannel.invokeMethod("maxAudioCallCount");
  }

  Future<void> seMaxVideoCallCount(int count) async {
    return await methodChannel.invokeMethod("seMaxVideoCallCount", {'count':count});
  }

  Future<void> seMaxAudioCallCount(int count) async {
    return await methodChannel.invokeMethod("seMaxAudioCallCount", {'count':count});
  }

  Future<void> addICEServer(String url, String name, String password) async {
    var args = {"url": url, "name": name, "password": password};
    return await methodChannel.invokeMethod("addICEServer", args);
  }

  Future<void> startSingleCall(String userId, bool audioOnly) async {
    var args = {"userId": userId, "audioOnly": audioOnly};
    return await methodChannel.invokeMethod("startSingleCall", args);
  }

  Future<void> startMultiCall(String groupId, List<String> participants, bool audioOnly) async {
    var args = {"groupId": groupId, "participants": participants, "audioOnly": audioOnly};
    return await methodChannel.invokeMethod("startMultiCall", args);
  }

  Future<void> setupAppServer(String appServerAddress, String authToken) async {
    return await methodChannel.invokeMethod("setupAppServer", {'appServerAddress':appServerAddress, 'authToken':authToken});
  }
  
  Future<void> showConferenceInfo(String conferenceId, String? password) async {
    return await methodChannel.invokeMethod("showConferenceInfo", {'conferenceId':conferenceId, 'password':password==null?"":password!});
  }

  Future<void> showConferencePortal() async {
    return await methodChannel.invokeMethod("showConferencePortal");
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
    Map<dynamic, dynamic> map = await methodChannel.invokeMethod('currentCallSession');
    return CallSession(map["callId"]);
  }

  Future<void> answerCall(bool audioOnly) async {
    return await methodChannel.invokeMethod("answerCall", {"audioOnly":audioOnly});
  }

  Future<void> endCall(String callId) async {
    return await methodChannel.invokeMethod("endCall", {'callId':callId});
  }
}
