import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imclient/imclient_method_channel.dart';
import 'package:momentclient/momentclient.dart';
import 'package:momentkit/momentkit.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../multi_window/sub_window_app_base.dart';
import 'moment_ipc.dart';
import 'moment_window_imclient_channel.dart';

/// 朋友圈窗口的入口 Widget。
///
/// 运行在独立的 Flutter Engine / Dart isolate 中，不连接 IM；
/// IM 调用经 [MomentWindowImclientChannel] 转发到主窗口执行，
/// 与 Call 窗口（CallWindowApp）同构。
/// 窗口初始化/标题/主题/关窗通知等样板见 [SubWindowAppBase]。
class MomentWindowApp extends StatefulWidget {
  final int windowId;
  final Map<String, dynamic> arguments;

  const MomentWindowApp({
    super.key,
    required this.windowId,
    required this.arguments,
  });

  @override
  State<MomentWindowApp> createState() => _MomentWindowAppState();
}

class _MomentWindowAppState extends State<MomentWindowApp>
    with WindowListener, SubWindowAppBase<MomentWindowApp> {
  /// 主窗口转发来的刷新信号（feedId：单条刷新；null：全量刷新）。
  final StreamController<int?> _refreshController =
      StreamController<int?>.broadcast();

  // -------------------------------------------------------------- 基类钩子

  @override
  int get windowId => widget.windowId;

  @override
  Map<String, dynamic> get windowArguments => widget.arguments;

  @override
  String get windowKind => kMomentWindowKind;

  @override
  Size get minWindowSize => const Size(480, 600);

  @override
  ImclientChannel get imclientChannel => MomentWindowImclientChannel();

  @override
  Map<String, Future<dynamic> Function(dynamic)> get eventHandlers => {
        MomentWindowEvents.refresh: _handleRefresh,
      };

  @override
  String windowTitle(AppLocalizations l10n) => l10n.momentWindowTitle;

  /// 注册朋友圈消息内容类型（仅 Dart 层解码用）。
  @override
  void registerMessageContents() {
    MomentClient.init((comment) {}, (feed) {});
  }

  @override
  Widget buildHome(BuildContext context) {
    return FeedListPage(refreshStream: _refreshController.stream);
  }

  // -------------------------------------------------------------- 业务

  Future<dynamic> _handleRefresh(dynamic args) async {
    final feedId = args is Map ? args['feedId'] as int? : null;
    _refreshController.add(feedId);
    return null;
  }

  @override
  void dispose() {
    _refreshController.close();
    super.dispose();
  }
}
