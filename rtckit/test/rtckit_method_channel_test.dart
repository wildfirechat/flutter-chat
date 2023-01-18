import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtckit/rtckit_method_channel.dart';

void main() {
  MethodChannelRtckit platform = MethodChannelRtckit();
  const MethodChannel channel = MethodChannel('rtckit');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {

  });
}
