export '../multi_window/window_kind.dart';

class WFWebViewWindowEvents {
  static const String ready = 'wfWebView.ready';
  static const String windowClosed = 'wfWebView.windowClosed';
  static const String openUrl = 'wfWebView.openUrl';
}

class WFWebViewWindowPayload {
  static const String kUrl = 'url';
  static const String kTitle = 'title';

  static Map<String, dynamic> encode({required String url, String? title}) {
    return {
      kUrl: url,
      if (title != null && title.isNotEmpty) kTitle: title,
    };
  }

  static String decodeUrl(Map<dynamic, dynamic> payload) {
    return payload[kUrl] as String? ?? '';
  }

  static String? decodeTitle(Map<dynamic, dynamic> payload) {
    final title = payload[kTitle] as String?;
    return title != null && title.isNotEmpty ? title : null;
  }
}

const String kWFWebViewWindowKind = 'wfWebView';
