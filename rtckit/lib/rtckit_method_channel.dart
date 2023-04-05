import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'rtckit_platform_interface.dart';

/// An implementation of [RtckitPlatform] that uses method channels.
class MethodChannelRtckit extends RtckitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('rtckit');

  @override
  Future<void> initProto() async {
    methodChannel.invokeMethod<String>('initProto');
  }

  @override
  Future<void> addICEServer(String url, String name, String password) async {
    var args = {"url": url, "name": name, "password": password};
    await methodChannel.invokeMethod("addICEServer", args);
  }

  @override
  Future<void> startSingleCall(String userId, bool audioOnly) async {
    var args = {"userId": userId, "audioOnly": audioOnly};
    await methodChannel.invokeMethod("startSingleCall", args);
  }

  @override
  Future<void> startMultiCall(String groupId, List<String> participants, bool audioOnly) async {
    var args = {"groupId": groupId, "participants": participants, "audioOnly": audioOnly};
    await methodChannel.invokeMethod("startMultiCall", args);
  }
}
