import 'dart:ffi';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'rtckit_method_channel.dart';

abstract class RtckitPlatform extends PlatformInterface {
  /// Constructs a RtckitPlatform.
  RtckitPlatform() : super(token: _token);

  static final Object _token = Object();

  static RtckitPlatform _instance = MethodChannelRtckit();

  /// The default instance of [RtckitPlatform] to use.
  ///
  /// Defaults to [MethodChannelRtckit].
  static RtckitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RtckitPlatform] when
  /// they register themselves.
  static set instance(RtckitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initProto() {
    throw UnimplementedError('initProto() has not been implemented.');
  }

  Future<void> addICEServer(String url, String name, String password) {
    throw UnimplementedError('addICEServer() has not been implemented.');
  }

  Future<void> startSingleCall(String userId, bool audioOnly) {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  Future<void> startMultiCall(String groupId, List<String> participants, bool audioOnly) {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }
}
