import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

import '../multi_window/sub_window_manager_base.dart';
import '../multi_window/window_event_channel.dart';

/// Call 窗口类型。
enum CallWindowType {
  single,
  multi,
  conference,
}

/// 管理 PC 端独立 Call 窗口的创建、显示、隐藏和销毁。
///
/// 复用策略为"先关再开"(reusePolicy = recreate):全局最多一个通话窗口,
/// 新通话先关旧窗再创建。就绪/关闭事件不经本类的 WindowEventChannel
/// handler,由 MainAvEngineKitProxy 收到 voipStatusChanged/voip.windowClosed
/// 后调 [onCallWindowReady]/[onCallWindowClosed]。创建序列等样板见
/// [SubWindowManagerBase]。
class CallWindowManager extends SubWindowManagerBase {
  static final CallWindowManager instance = CallWindowManager._internal();

  CallWindowManager._internal();

  /// 窗口创建参数。
  final Map<int, _CallWindowCreationContext> _creationContexts = {};

  /// 下一次创建窗口用的参数(createCallWindow 暂存,createAndShow 取用)。
  String _pendingType = 'conference';
  Map<String, dynamic>? _pendingArguments;
  VoidCallback? _pendingOnReady;
  VoidCallback? _pendingOnClose;

  @override
  String get windowKind => 'call';

  @override
  SubWindowReusePolicy get reusePolicy => SubWindowReusePolicy.recreate;

  /// 通话的就绪/关闭由 MainAvEngineKitProxy 路由,不注册本类 handler。
  @override
  void registerManagerHandlers(WindowEventChannel channel) {}

  @override
  Map<String, dynamic> createPayload() => {
        ...?_pendingArguments,
        '_windowType': _pendingType,
      };

  @override
  Size initialWindowSize() => _windowSizeFor(parseWindowType(_pendingType));

  @override
  void onWindowCreated(WindowController controller) {
    debugPrint('$windowKind window created id=${controller.windowId}');
    _creationContexts[controller.windowId] = _CallWindowCreationContext(
      onReady: _pendingOnReady!,
      onClose: _pendingOnClose!,
    );
  }

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
    debugPrint('$windowKind createCallWindow $type');
    final existing = windowController;
    if (existing != null) {
      debugPrint('$windowKind close existing window');
      try {
        await existing.close();
      } catch (e) {
        debugPrint('$windowKind close existing window failed: $e');
      }
      clearWindowState();
      _creationContexts.clear();
    }

    _pendingType = type;
    _pendingArguments = arguments ?? {};
    _pendingOnReady = onReady;
    _pendingOnClose = onClose;

    final controller = await createAndShow();
    debugPrint('$windowKind window centered and shown');
    return controller.windowId;
  }

  /// 通知 Call 窗口已就绪，可以显示。
  Future<void> onCallWindowReady(int windowId) async {
    final ctx = _creationContexts[windowId];
    if (ctx == null) return;

    debugPrint('$windowKind onCallWindowReady $windowId');
    await windowController?.center();
    await windowController?.show();
    ctx.onReady();
  }

  /// 通知 Call 窗口已关闭。
  Future<void> onCallWindowClosed(int windowId) async {
    final ctx = _creationContexts.remove(windowId);
    if (ctx == null) return;

    clearWindowState();
    ctx.onClose();
  }

  /// 关闭当前 Call 窗口。
  Future<void> closeCallWindow() async {
    final controller = windowController;
    if (controller == null) return;
    await controller.close();
    clearWindowState();
  }

  /// 隐藏当前 Call 窗口（例如屏幕共享时缩为控制条）。
  Future<void> hideCallWindow() async {
    await windowController?.hide();
  }

  /// 显示当前 Call 窗口。
  Future<void> showCallWindow() async {
    await windowController?.show();
  }

  /// 调整当前 Call 窗口尺寸。
  Future<void> setFrame(Rect frame) async {
    await windowController?.setFrame(frame);
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
