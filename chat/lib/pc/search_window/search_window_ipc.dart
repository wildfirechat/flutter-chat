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

/// 搜索窗口 → 主窗口 的 IM 代理事件名。
///
/// 搜索窗口不连接 IM，所有 Imclient 调用经这些事件转发给主窗口执行，
/// 与朋友圈窗口的 moment.imclient.* 代理同构（见 MainMomentProxy）。
class SearchMainEvents {
  static const String getMessages = 'search.imclient.getMessages';
  static const String searchMessages = 'search.imclient.searchMessages';
  static const String getMessagesByTimestamp =
      'search.imclient.getMessagesByTimestamp';
  static const String getMessageCountByDay =
      'search.imclient.getMessageCountByDay';
  static const String getUserInfo = 'search.imclient.getUserInfo';
  static const String getConversationFiles =
      'search.imclient.getConversationFiles';
  static const String searchFiles = 'search.imclient.searchFiles';
  static const String getAuthorizedMediaUrl =
      'search.imclient.getAuthorizedMediaUrl';
  static const String deleteFileRecord = 'search.imclient.deleteFileRecord';
}

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
