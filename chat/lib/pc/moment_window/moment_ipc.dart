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

// 朋友圈窗口的 IM 调用事件名已全部并入共享域 `im.*`
// (见 multi_window/shared_imclient_channel.dart + main_imclient_proxy.dart),
// 原 MomentMainEvents 已删除。
