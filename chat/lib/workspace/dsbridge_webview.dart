import 'dart:async';

import 'package:dsbridge_flutter/dsbridge_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/workspace/js_api.dart';
import 'package:chat/workspace/webview_background.dart';
import 'package:chat/workspace/webview_support.dart';

typedef DsBridgePageFinished = Future<void> Function(String url);

/// 配置带 JsApi 的 WebView:统一 JavaScript、导航回调与对象注入。
void configureDsBridgeWebView({
  required DWebViewController controller,
  required JsApi jsApi,
  required DsBridgePageFinished onPageFinished,
  void Function(String url)? onUrlChange,
}) {
  controller
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          debugPrint('WebView is loading (progress : $progress%)');
        },
        onPageStarted: (String url) {
          debugPrint('Page started loading: $url');
        },
        onPageFinished: (String url) {
          debugPrint('Page finished loading: $url');
          unawaited(onPageFinished(url));
        },
        onUrlChange: (UrlChange urlChange) {
          final url = urlChange.url;
          if (url != null) {
            onUrlChange?.call(url);
          }
        },
        onNavigationRequest: (NavigationRequest request) {
          if (request.url.startsWith('https://www.youtube.com/')) {
            debugPrint('blocking navigation to ${request.url}');
            return NavigationDecision.prevent;
          }
          debugPrint('allowing navigation to ${request.url}');
          return NavigationDecision.navigate;
        },
      ),
    )
    ..addJavaScriptObject(jsApi);

  unawaited(setTransparentBackground(controller));
}

/// 让桌面 WebView 的 UA 带上 dsbridge 标记,必须在 loadRequest 之前调用。
Future<void> ensureDesktopDsBridgeUserAgent(
    DWebViewController controller) async {
  if (!isDesktopShell) {
    return;
  }
  await tagDsBridgeUserAgent(controller);
}
