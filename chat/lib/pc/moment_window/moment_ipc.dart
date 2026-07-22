// 窗口种类常量(含 kMomentWindowKind)已集中到 multi_window/window_kind.dart,
// 此处再导出以兼容现有 import。
export '../multi_window/window_kind.dart';

/// 主窗口 → 朋友圈窗口 的事件名。
class MomentWindowEvents {
  /// 朋友圈窗口 → 主窗口：窗口已就绪。
  static const String ready = 'moment.ready';

  /// 主窗口 → 朋友圈窗口：某条 feed 数据变化（feedId 为空表示全量刷新）。
  static const String refresh = 'moment.refresh';

  /// 朋友圈窗口 → 主窗口：窗口已关闭。
  static const String windowClosed = 'moment.windowClosed';
}

/// 朋友圈窗口 → 主窗口 的 IM 代理事件名。
///
/// 朋友圈窗口不连接 IM，所有 [Imclient] 调用经这些事件转发给主窗口执行，
/// 与 Call 窗口的 imclient.* 代理同构（见 CallWindowImclientChannel）。
class MomentMainEvents {
  static const String sendMomentsRequest = 'moment.imclient.sendMomentsRequest';
  static const String getUserInfo = 'moment.imclient.getUserInfo';
  static const String getUserInfos = 'moment.imclient.getUserInfos';
  static const String getConversationsMessageByStatus =
      'moment.imclient.getConversationsMessageByStatus';
  static const String getConversationsUnreadCount =
      'moment.imclient.getConversationsUnreadCount';
  static const String clearConversationsUnreadStatus =
      'moment.imclient.clearConversationsUnreadStatus';
  static const String uploadMedia = 'moment.imclient.uploadMedia';
  static const String uploadMediaFile = 'moment.imclient.uploadMediaFile';
  static const String serverDeltaTime = 'moment.imclient.serverDeltaTime';
}
