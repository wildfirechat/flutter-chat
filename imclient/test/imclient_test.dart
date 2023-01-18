import 'package:flutter_test/flutter_test.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/imclient_platform_interface.dart';
import 'package:imclient/imclient_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';


void main() {
  final ImclientPlatform initialPlatform = ImclientPlatform.instance;

  test('$MethodChannelImclient is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelImclient>());
  });

  test('getPlatformVersion', () async {
    
  });
}
