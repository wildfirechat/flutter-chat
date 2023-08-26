import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';


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
