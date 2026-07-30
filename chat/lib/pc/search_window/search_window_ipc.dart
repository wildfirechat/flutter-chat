import 'package:imclient/model/conversation.dart';

import '../multi_window/ipc_codec.dart';

// 窗口种类常量(含 kSearchWindowKind)已集中到 multi_window/window_kind.dart,
// 此处再导出以兼容现有 import。
export '../multi_window/window_kind.dart';

/// 搜索窗口 ↔ 主窗口 的事件名。
class SearchWindowEvents {
  /// 搜索窗口 → 主窗口：窗口已就绪。
  static const String ready = 'search.ready';

  /// 主窗口 → 搜索窗口：窗口复用时切换搜索目标会话。
  static const String updateConversation = 'search.updateConversation';

  /// 搜索窗口 → 主窗口：点击搜索结果，定位到会话内对应消息。
  static const String locateMessage = 'search.locateMessage';

  /// 搜索窗口 → 主窗口：窗口已关闭。
  static const String windowClosed = 'search.windowClosed';
}

// 搜索窗口的 IM 调用事件名已全部并入共享域 `im.*`
// (见 multi_window/shared_imclient_channel.dart + main_imclient_proxy.dart),
// 原 SearchMainEvents 已删除。

/// 搜索窗口创建参数 / updateConversation 事件的 payload 编解码。
class SearchWindowPayload {
  static Map<String, dynamic> encode(
    Conversation conversation,
    String conversationTitle, {
    String keyword = '',
  }) {
    return {
      'conversation': IpcCodec.encodeConversation(conversation),
      'conversationTitle': conversationTitle,
      'keyword': keyword,
    };
  }

  static Conversation decodeConversation(Map<dynamic, dynamic> payload) {
    return IpcCodec.decodeConversation(
        payload['conversation'] as Map<dynamic, dynamic>? ?? const {});
  }

  static String decodeTitle(Map<dynamic, dynamic> payload) {
    return payload['conversationTitle'] as String? ?? '';
  }

  static String decodeKeyword(Map<dynamic, dynamic> payload) {
    return payload['keyword'] as String? ?? '';
  }
}
