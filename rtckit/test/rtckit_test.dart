import 'package:flutter_test/flutter_test.dart';
import 'package:rtckit/rtckit.dart';
import 'package:rtckit/rtckit_platform_interface.dart';
import 'package:rtckit/rtckit_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';


void main() {
  final RtckitPlatform initialPlatform = RtckitPlatform.instance;

  test('$MethodChannelRtckit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRtckit>());
  });

  test('getPlatformVersion', () async {

  });
}
