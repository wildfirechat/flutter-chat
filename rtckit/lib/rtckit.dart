
import 'dart:ffi';

import 'package:rtckit/rtckit_method_channel.dart';


class Rtckit {
  static void init() {
    RtckitPlatform.instance.initProto();
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
}
