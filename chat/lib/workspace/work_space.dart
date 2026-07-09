import 'dart:async';

import 'package:dsbridge_flutter/dsbridge_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:chat/config.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/workspace/js_api.dart';
import 'package:chat/workspace/webview_background.dart';
import 'package:chat/utils/media_url_redirector.dart';

// TODO: Potentially add imports for contact picking and navigation if needed for chooseContacts and openUrl

class WorkSpace extends StatefulWidget {
  const WorkSpace({super.key});

  @override
  State<WorkSpace> createState() => _WorkSpaceState();
}

class _WorkSpaceState extends State<WorkSpace> {
  late final DWebViewController _controller;

  /// 工作台是远端 H5,明暗只能由宿主用 URL 上的 `?theme=` 告诉它(与 vue-pc-chat 一致)。
  /// 记住上次加载用的明暗,主题变了才重新 load,避免每次 didChangeDependencies 都刷页面。
  Brightness? _loadedBrightness;

  @override
  void initState() {
    super.initState();

    final DWebViewController controller = DWebViewController();
    _clearInvalidWebViewCookies(controller);

    unawaited(setTransparentBackground(controller));

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
      ..addJavaScriptObject(JsApi(context, Config.workspaceUrl ?? '', controller));

    // 首次加载推迟到 didChangeDependencies:initState 里拿不到解析后的明暗。
    _controller = controller;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme.of 注册依赖,应用切明暗时会再次走到这里
    final brightness = Theme.of(context).brightness;
    if (brightness != _loadedBrightness) {
      _loadedBrightness = brightness;
      _loadWorkspace(brightness);
    }
  }

  void _loadWorkspace(Brightness brightness) {
    final workspaceUrl = Config.workspaceUrl;
    if (workspaceUrl == null || workspaceUrl.isEmpty) {
      // Load a default local page if WORKSPACE_URL is not set
      // controller.loadHtmlString(_kExamplePage);
      return;
    }
    _controller.loadRequest(workspaceUriWithTheme(MediaUrlRedirector.redirect(workspaceUrl), brightness));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 18,
              width: double.infinity, // Use double.infinity for full width
              color: context.colors.sectionGap,
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

  void _clearInvalidWebViewCookies(DWebViewController controller) async {
    var sp = await SharedPreferences.getInstance();
    var webViewUserId = sp.getString('webview-userId');
    if (webViewUserId == null) {
      sp.setString('webview-userId', Imclient.currentUserId);
      return;
    } else if (webViewUserId == Imclient.currentUserId) {
      return;
    }
    controller.clearCache();
    controller.clearLocalStorage();
  }
}

Uri workspaceUriWithTheme(String urlString, Brightness brightness) {
  final uri = Uri.parse(urlString);
  final themeValue = brightness == Brightness.dark ? 'dark' : 'light';
  final queryParams = Map<String, String>.from(uri.queryParameters);
  queryParams['theme'] = themeValue;
  return uri.replace(queryParameters: queryParams);
}

