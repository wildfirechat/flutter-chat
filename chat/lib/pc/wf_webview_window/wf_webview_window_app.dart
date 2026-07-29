import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../../workspace/wf_webview_screen.dart';
import '../multi_window/sub_window_app_base.dart';
import 'package:imclient/imclient_method_channel.dart';
import 'wf_webview_window_imclient_channel.dart';
import 'wf_webview_window_ipc.dart';

class WFWebViewWindowApp extends StatefulWidget {
  final int windowId;
  final Map<String, dynamic> arguments;

  const WFWebViewWindowApp({
    super.key,
    required this.windowId,
    required this.arguments,
  });

  @override
  State<WFWebViewWindowApp> createState() => _WFWebViewWindowAppState();
}

class _WFWebViewWindowAppState extends State<WFWebViewWindowApp>
    with WindowListener, SubWindowAppBase<WFWebViewWindowApp> {
  String _url = '';
  String? _title;

  @override
  int get windowId => widget.windowId;

  @override
  Map<String, dynamic> get windowArguments => widget.arguments;

  @override
  String get windowKind => kWFWebViewWindowKind;

  @override
  Size get minWindowSize => const Size(480, 600);

  @override
  bool get useNormalTitleBar => true;

  @override
  ImclientChannel get imclientChannel => WFWebViewWindowImclientChannel();

  @override
  Map<String, Future<dynamic> Function(dynamic)> get eventHandlers => {
        WFWebViewWindowEvents.openUrl: _handleOpenUrl,
      };

  @override
  String windowTitle(AppLocalizations l10n) => _title ?? l10n.webOnline;

  @override
  Future<void> onWindowReady() async {
    _applyPayload(windowArguments);
  }

  @override
  Widget buildHome(BuildContext context) {
    return WFWebViewScreen(_url, title: _title);
  }


  void _applyPayload(Map<dynamic, dynamic> args) {
    _url = WFWebViewWindowPayload.decodeUrl(args);
    _title = WFWebViewWindowPayload.decodeTitle(args);
    if (_url.isEmpty) {
      return;
    }
    updateWindowTitle();
  }

  Future<dynamic> _handleOpenUrl(dynamic args) async {
    if (args is! Map) {
      return null;
    }
    setState(() {
      _applyPayload(args);
    });
    updateWindowTitle();
    return null;
  }
}
