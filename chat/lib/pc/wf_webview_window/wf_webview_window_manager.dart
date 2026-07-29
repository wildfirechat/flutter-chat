import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

import '../multi_window/sub_window_manager_base.dart';
import '../multi_window/window_event_channel.dart';
import 'wf_webview_window_ipc.dart';

class WFWebViewWindowManager extends SubWindowManagerBase {
  static final WFWebViewWindowManager instance =
      WFWebViewWindowManager._internal();

  WFWebViewWindowManager._internal();

  String? _url;
  String? _title;

  @override
  String get windowKind => kWFWebViewWindowKind;

  @override
  String get creationWindowKind => kWFWebViewWindowKind;

  @override
  SubWindowReusePolicy get reusePolicy => SubWindowReusePolicy.updateContent;

  @override
  Map<String, dynamic> createPayload() => WFWebViewWindowPayload.encode(
        url: _url ?? '',
        title: _title,
      );

  @override
  Size initialWindowSize() => const Size(880, 760);

  Future<void> show({required String url, String? title}) async {
    installHandlers();
    _url = url;
    _title = title;
    if (await reuseExistingWindow()) return;
    await createAndShow();
  }

  @override
  Future<void> onReuseContent(WindowController controller) async {
    if (windowReady) {
      await WindowEventChannel.invoke(
        controller.windowId,
        WFWebViewWindowEvents.openUrl,
        WFWebViewWindowPayload.encode(url: _url ?? '', title: _title),
      );
    }
  }

  @override
  Future<void> onSubWindowReady(int windowId) async {
    final url = _url;
    if (url != null && url.isNotEmpty) {
      await WindowEventChannel.invoke(
        windowId,
        WFWebViewWindowEvents.openUrl,
        WFWebViewWindowPayload.encode(url: url, title: _title),
      );
    }
  }
}
