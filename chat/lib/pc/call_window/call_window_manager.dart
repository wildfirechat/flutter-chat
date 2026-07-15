import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';

/// Call 窗口类型。
enum CallWindowType {
  single,
  multi,
  conference,
}

/// 管理 PC 端独立 Call 窗口的创建、显示、隐藏和销毁。
class CallWindowManager {
  static const String _tag = 'CallWindowManager';
  static final CallWindowManager instance = CallWindowManager._internal();

  CallWindowManager._internal();

  /// 当前已创建的 Call 窗口控制器。
  WindowController? _windowController;

  /// 窗口创建参数。
  final Map<int, _CallWindowCreationContext> _creationContexts = {};

  /// 创建 Call 窗口。
  ///
  /// [type] 决定窗口尺寸：
  /// - single: 432 × 768
  /// - multi: 960 × 600
  /// - conference: 960 × 600（无边框、透明背景）
  ///
  /// [arguments] 会作为 JSON 字符串传给子窗口。
  /// [onReady] 窗口加载完成并可接收事件时回调。
  /// [onClose] 窗口关闭时回调。
  Future<int> createCallWindow({
    required String type,
    required VoidCallback onReady,
    required VoidCallback onClose,
    Map<String, dynamic>? arguments,
  }) async {
    print('$_tag createCallWindow $type');
    if (_windowController != null) {
      print('$_tag close existing window');
      try {
        await _windowController!.close();
      } catch (e) {
        print('$_tag close existing window failed: $e');
      }
      _windowController = null;
      _creationContexts.clear();
    }

    final windowType = parseWindowType(type);
    final args = arguments ?? {};
    args['_windowType'] = type;
    args['_selfUserId'] = Imclient.currentUserId;
    print('$_tag createWindow args=$args');

    final WindowController controller;
    try {
      controller = await DesktopMultiWindow.createWindow(jsonEncode(args));
    } catch (e) {
      print('$_tag createWindow failed: $e');
      rethrow;
    }
    _windowController = controller;
    print('$_tag window created id=${controller.windowId}');

    _creationContexts[controller.windowId] = _CallWindowCreationContext(
      onReady: onReady,
      onClose: onClose,
    );

    // 先显示窗口（否则子窗口 window_manager 初始化时无法获取 view.window）。
    // 子窗口初始显示黑色加载页，等收到 startCall 事件后再渲染通话 UI。
    await _applyWindowStyle(controller, windowType);
    await controller.show();
    await controller.center();
    print('$_tag window shown and centered');

    return controller.windowId;
  }

  /// 通知 Call 窗口已就绪，可以显示。
  Future<void> onCallWindowReady(int windowId) async {
    final ctx = _creationContexts[windowId];
    if (ctx == null) return;

    print('$_tag onCallWindowReady $windowId');
    await _windowController?.center();
    await _windowController?.show();
    ctx.onReady();
  }

  /// 通知 Call 窗口已关闭。
  Future<void> onCallWindowClosed(int windowId) async {
    final ctx = _creationContexts.remove(windowId);
    if (ctx == null) return;

    _windowController = null;
    ctx.onClose();
  }

  /// 关闭当前 Call 窗口。
  Future<void> closeCallWindow() async {
    if (_windowController == null) return;
    await _windowController!.close();
    _windowController = null;
  }

  /// 隐藏当前 Call 窗口（例如屏幕共享时缩为控制条）。
  Future<void> hideCallWindow() async {
    await _windowController?.hide();
  }

  /// 显示当前 Call 窗口。
  Future<void> showCallWindow() async {
    await _windowController?.show();
  }

  /// 调整当前 Call 窗口尺寸。
  Future<void> setFrame(Rect frame) async {
    await _windowController?.setFrame(frame);
  }

  Future<void> _applyWindowStyle(WindowController controller, CallWindowType type) async {
    final size = _windowSizeFor(type);

    // 标题、无边框等样式由子窗口在启动后按自身 locale 通过 window_manager 设置。
    await controller.setFrame(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
  }

  Size _windowSizeFor(CallWindowType type) {
    switch (type) {
      case CallWindowType.single:
        // PC 端 single 在 360×640 基础上增加 20%。
        return const Size(432, 768);
      case CallWindowType.multi:
      case CallWindowType.conference:
        return const Size(960, 600);
    }
  }

  /// 解析窗口类型字符串。
  CallWindowType parseWindowType(String type) {
    switch (type) {
      case 'single':
        return CallWindowType.single;
      case 'multi':
        return CallWindowType.multi;
      case 'conference':
      default:
        return CallWindowType.conference;
    }
  }
}

class _CallWindowCreationContext {
  final VoidCallback onReady;
  final VoidCallback onClose;

  _CallWindowCreationContext({
    required this.onReady,
    required this.onClose,
  });
}
