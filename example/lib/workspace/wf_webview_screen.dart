
import 'package:dsbridge_flutter/dsbridge_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wfc_example/workspace/js_api.dart';

class WFWebViewScreen extends StatefulWidget {
  final String url;
  final String? title;

  const WFWebViewScreen(this.url, {this.title, super.key});

  @override
  State<WFWebViewScreen> createState() => _WFWebViewScreenState();
}

class _WFWebViewScreenState extends State<WFWebViewScreen> {
  late final DWebViewController _controller;
  late String _pageTitle;

  @override
  void initState() {
    super.initState();
    _pageTitle = widget.title ?? '';

    final DWebViewController controller = DWebViewController();
    final jsApi = JsApi(context, widget.url, controller);

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
          onPageFinished: (String url) async {
            debugPrint('Page finished loading: $url');
            String? title = await _controller.getTitle();
            setState(() {
              _pageTitle = title ?? '';
            });
          },
          onUrlChange: (UrlChange urlChange) {
            jsApi.setCurrentUrl(urlChange.url!);
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

    controller.loadRequest(Uri.parse(widget.url));

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
      ),
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
