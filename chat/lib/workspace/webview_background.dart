import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 把 WebView 背景设为透明。
///
/// macOS 版 webview_flutter 未实现 setOpaque，平台层会异步抛错，
/// 同步 try/catch 拦不住，必须 await 后再捕获。失败时背景退化为不透明，
/// 不影响页面展示，因此只记日志。
Future<void> setTransparentBackground(WebViewController controller) async {
  try {
    await controller.setBackgroundColor(const Color(0x00000000));
  } catch (e) {
    debugPrint('WebView setBackgroundColor skipped on this platform: $e');
  }
}
