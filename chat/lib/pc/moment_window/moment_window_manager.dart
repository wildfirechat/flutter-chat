import 'package:flutter/material.dart';

import '../multi_window/sub_window_manager_base.dart';
import '../multi_window/window_event_channel.dart';
import 'moment_ipc.dart';

/// 管理 PC 端独立的朋友圈窗口。
///
/// 全局最多一个朋友圈窗口：已打开时再次进入只置顶，不重复开窗。
/// 子窗口不连接 IM，数据请求由子窗口经 IPC 转发给主窗口执行
/// （见 MainMomentProxy）。创建序列/ready/closed 等样板见
/// [SubWindowManagerBase]。
class MomentWindowManager extends SubWindowManagerBase {
  static final MomentWindowManager instance = MomentWindowManager._internal();

  MomentWindowManager._internal();

  @override
  String get windowKind => kMomentWindowKind;

  @override
  SubWindowReusePolicy get reusePolicy => SubWindowReusePolicy.raiseOnly;

  @override
  Map<String, dynamic> createPayload() => {};

  @override
  Size initialWindowSize() => const Size(960, 720);

  /// 打开（或置顶）朋友圈窗口。
  Future<void> show() async {
    installHandlers();
    if (await reuseExistingWindow()) return;
    await createAndShow();
  }

  /// 通知子窗口某条 feed 数据变化（[feedId] 为空表示全量刷新）。
  void notifyFeedChanged(int? feedId) {
    if (!isReady) return;
    WindowEventChannel.invoke(
        windowController!.windowId, MomentWindowEvents.refresh, {
      'feedId': feedId,
    }).catchError((e) {
      // 窗口可能已被系统关闭按钮销毁,而主窗口这边还没收到 windowClosed
      // (Linux 上收不到,见 SubWindowManagerBase.ensureWindowAlive)。
      // 这里是 fire-and-forget,不接住会变成未处理异常。
      debugPrint('$windowKind notifyFeedChanged failed: $e');
      return null;
    });
  }
}
