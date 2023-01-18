import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imclient/imclient_method_channel.dart';

void main() {
  MethodChannelImclient platform = MethodChannelImclient();
  const MethodChannel channel = MethodChannel('imclient');

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
