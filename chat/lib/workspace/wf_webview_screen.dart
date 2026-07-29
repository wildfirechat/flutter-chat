import 'dart:async';

import 'package:dsbridge_flutter/dsbridge_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:chat/workspace/dsbridge_webview.dart';
import 'package:chat/workspace/js_api.dart';
import 'package:chat/workspace/webview_support.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';

class WFWebViewScreen extends StatefulWidget {
  final String url;
  final String? title;

  const WFWebViewScreen(this.url, {this.title, super.key});

  @override
  State<WFWebViewScreen> createState() => _WFWebViewScreenState();
}

class _WFWebViewScreenState extends State<WFWebViewScreen> {
  /// 平台没有 WebView 实现时保持为 null,页面退化成"用系统浏览器打开"。
  DWebViewController? _controller;
  late String _pageTitle;

  /// 有全屏内容(联系人选择、内嵌网页跳转等)盖住本页时置 true,build() 据此
  /// 摘掉 [WebViewWidget]。见 [JsApi.pushOverlay] 的用法说明。
  bool _hideForOverlay = false;

  @override
  void initState() {
    super.initState();
    _pageTitle = widget.title ?? '';

    if (!isInlineWebViewSupported) {
      return;
    }

    final DWebViewController controller = DWebViewController();
    final jsApi = JsApi(context, widget.url, controller, pushOverlay: _pushOverlay);

    configureDsBridgeWebView(
      controller: controller,
      jsApi: jsApi,
      onPageFinished: (_) async {
        final String? title = await controller.getTitle();
        if (!mounted) {
          return;
        }
        setState(() {
          _pageTitle = title ?? '';
        });
      },
      onUrlChange: jsApi.setCurrentUrl,
    );

    unawaited(() async {
      // 同工作台:UA 上的标记决定页面选不选 dsbridge 传输,必须赶在加载之前。
      await ensureDesktopDsBridgeUserAgent(controller);
      await controller.loadRequest(Uri.parse(MediaUrlRedirector.redirect(widget.url)));
    }());

    _controller = controller;
  }

  Future<void> _pushOverlay(WidgetBuilder builder) async {
    if (!mounted) {
      return;
    }
    setState(() => _hideForOverlay = true);
    await Navigator.push(context, MaterialPageRoute(builder: builder));
    if (mounted) {
      setState(() => _hideForOverlay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: _pageTitle,
            )
          : AppBar(
              title: Text(_pageTitle),
            ),
      body: SafeArea(
        child: controller == null
            ? WebViewUnsupportedView(url: widget.url)
            : Column(
                children: [
                  Container(
                    height: 18,
                    width: double.infinity, // Use double.infinity for full width
                    color: const Color(0xffebebeb),
                  ),
                  Expanded(
                    child: _hideForOverlay
                        ? const SizedBox.shrink()
                        : WebViewWidget(
                            controller: controller,
                            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
