import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';

import '../media_preview_window/media_preview_ipc.dart';
import '../multi_window/window_event_channel.dart';
import 'moment_ipc.dart';

/// 管理 PC 端独立的朋友圈窗口。
///
/// 全局最多一个朋友圈窗口：已打开时再次进入只置顶，不重复开窗。
/// 子窗口不连接 IM，数据请求由子窗口经 IPC 转发给主窗口执行
/// （见 MainMomentProxy）。
class MomentWindowManager {
  static const String _tag = 'MomentWindowManager';
  static final MomentWindowManager instance = MomentWindowManager._internal();

  MomentWindowManager._internal();

  WindowController? _windowController;
  bool _windowReady = false;
  bool _handlersInstalled = false;

  int? get windowId => _windowController?.windowId;

  bool get isReady =>
      _windowController != null && _windowReady;

  /// 打开（或置顶）朋友圈窗口。
  Future<void> show() async {
    _installHandlers();

    final controller = _windowController;
    if (controller != null) {
      try {
        await controller.show();
      } catch (e) {
        print('$_tag show existing window failed: $e');
        _windowController = null;
        _windowReady = false;
      }
      if (_windowController != null) return;
    }

    final payload = <String, dynamic>{
      kWindowKindKey: kMomentWindowKind,
      '_selfUserId': Imclient.currentUserId,
    };

    final WindowController created;
    try {
      created = await DesktopMultiWindow.createWindow(jsonEncode(payload));
    } catch (e) {
      print('$_tag createWindow failed: $e');
      rethrow;
    }
    _windowController = created;
    _windowReady = false;

    // 与媒体预览窗口一致：先定尺寸，先 center 再 show，避免窗口在角落闪现。
    await created.setFrame(const Rect.fromLTWH(0, 0, 960, 720));
    await created.center();
    await created.show();
  }

  /// 通知子窗口某条 feed 数据变化（[feedId] 为空表示全量刷新）。
  void notifyFeedChanged(int? feedId) {
    if (!isReady) return;
    WindowEventChannel.invoke(
        _windowController!.windowId, MomentWindowEvents.refresh, {
      'feedId': feedId,
    });
  }

  void _installHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;
    final channel = WindowEventChannel();
    channel.register(MomentWindowEvents.ready, _handleReady);
    channel.register(MomentWindowEvents.windowClosed, _handleWindowClosed);
    channel.listen();
  }

  Future<dynamic> _handleReady(dynamic args) async {
    final windowId = args['windowId'] as int?;
    if (windowId == null || windowId != _windowController?.windowId) return null;
    _windowReady = true;
    return null;
  }

  Future<dynamic> _handleWindowClosed(dynamic args) async {
    // 快速重开时旧窗口迟到的关闭事件不能清掉新窗口的状态，按 windowId 过滤。
    final windowId = args['windowId'] as int?;
    if (windowId != null &&
        _windowController != null &&
        windowId != _windowController!.windowId) {
      return null;
    }
    _windowController = null;
    _windowReady = false;
    return null;
  }
}
