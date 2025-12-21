import 'dart:convert'; // Added for jsonDecode/jsonEncode

import 'package:dsbridge_flutter/dsbridge_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:chat/config.dart';
import 'package:chat/workspace/js_api.dart';

// TODO: Potentially add imports for contact picking and navigation if needed for chooseContacts and openUrl

class WorkSpace extends StatefulWidget {
  const WorkSpace({super.key});

  @override
  State<WorkSpace> createState() => _WorkSpaceState();
}

class _WorkSpaceState extends State<WorkSpace> {
  late final DWebViewController _controller;

  @override
  void initState() {
    super.initState();

    final DWebViewController controller = DWebViewController();

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
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
      ..addJavaScriptObject(JsApi(context, Config.WORKSPACE_URL, controller));

    if (Config.WORKSPACE_URL != null && Config.WORKSPACE_URL!.isNotEmpty) {
      controller.loadRequest(Uri.parse(Config.WORKSPACE_URL!));
    } else {
      // Load a default local page if WORKSPACE_URL is not set
      // controller.loadHtmlString(_kExamplePage);
    }

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 18,
              width: double.infinity, // Use double.infinity for full width
              color: const Color(0xffebebeb),
            ),
            Expanded(
              child: WebViewWidget(
                controller: _controller,
                gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
