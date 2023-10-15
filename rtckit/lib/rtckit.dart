
import 'dart:ffi';

import 'package:rtckit/rtckit_method_channel.dart';


class CallSession {
  String callId;

  CallSession(this.callId);
}

class Rtckit {
  static void init() {
    RtckitPlatform.instance.initProto();
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

  static Future<void> startSingleCall(String userId, bool audioOnly) async {
      return RtckitPlatform.instance.startSingleCall(userId, audioOnly);
  }

  static Future<void> startMultiCall(String groupId, List<String> participants, bool audioOnly) async {
    return RtckitPlatform.instance.startMultiCall(groupId, participants, audioOnly);
  }

  static Future<void> setupAppServer(String appServerAddress, String authToken) async {
    return RtckitPlatform.instance.setupAppServer(appServerAddress, authToken);
  }

  static Future<void> showConferenceInfo(String conferenceId, String? password) async {
    return RtckitPlatform.instance.showConferenceInfo(conferenceId, password);
  }

  static Future<void> showConferencePortal() async {
    return RtckitPlatform.instance.showConferencePortal();
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

  static Future<void> answerCall(bool audioOnly) async {
    return RtckitPlatform.instance.answerCall(audioOnly);
  }

  static Future<void> endCall(String callId) async {
    return RtckitPlatform.instance.endCall(callId);
  }
}
