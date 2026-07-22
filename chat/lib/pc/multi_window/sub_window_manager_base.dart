import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';
import 'package:imclient/imclient.dart';

import 'window_event_channel.dart';
import 'window_kind.dart';

/// 已存在子窗口时再次请求展示的复用策略。
enum SubWindowReusePolicy {
  /// 仅置顶(朋友圈)。
  raiseOnly,

  /// 置顶前先发内容更新事件(搜索发 updateConversation)。
  /// 媒体预览语义上也是换内容,但未就绪时的 pending 补发逻辑特殊,
  /// 直接覆写 reuseExistingWindow。
  updateContent,

  /// 不复用:先关再开(通话,见其 createCallWindow 的内联实现)。
  recreate,
}

/// PC 主窗口侧子窗口管理器基类:收敛四个子窗口 Manager(call/mediaPreview/
/// moment/search)的重复样板——`_windowController`/`_windowReady`/
/// `_handlersInstalled` 三字段、create→setFrame→center→show 创建序列、
/// ready/closed 事件处理、WindowEventChannel handler 懒安装。
///
/// 子类钩子:
/// - [windowKind]:子窗口标识,兼作 `<kind>.ready`/`<kind>.windowClosed`
///   事件前缀;
/// - [creationWindowKind]:创建参数 kWindowKindKey 的值,默认同 windowKind
///   (媒体预览:事件前缀 'mediaPreview',创建参数值 'media_preview',两者不同);
/// - [injectSelfUserId]:创建参数是否注入 _selfUserId(媒体预览不连 IM,关闭);
/// - [createPayload]/[initialWindowSize]:创建参数(业务部分)与首开尺寸;
/// - [reusePolicy]:复用策略,驱动 [reuseExistingWindow] 默认实现;
/// - [onReuseContent]:updateContent 策略下置顶前的内容更新;
/// - [onSubWindowReady]:ready 后的补发钩子(搜索补发最新搜索目标,
///   媒体预览补发 pending show);
/// - [managerHandlers]:额外注册的 manager 侧 handler(媒体预览的 loadMore);
/// - [onWindowCreated]/[onSubWindowClosed]:创建/关闭后的补充钩子。
abstract class SubWindowManagerBase {
  // -------------------------------------------------------------- 子类钩子

  /// 子窗口标识,兼作 ready/closed 事件前缀。
  String get windowKind;

  /// 创建参数 kWindowKindKey 的值;默认同 [windowKind]。
  String get creationWindowKind => windowKind;

  /// 创建参数是否注入 `_selfUserId`(连接 IM 的子窗口需要)。
  bool get injectSelfUserId => true;

  /// 创建参数的业务部分;[createAndShow] 会再注入 kWindowKindKey 与
  /// _selfUserId(按 [injectSelfUserId])。
  Map<String, dynamic> createPayload();

  /// 首开窗口尺寸。
  Size initialWindowSize();

  /// 复用策略,见 [SubWindowReusePolicy]。
  SubWindowReusePolicy get reusePolicy;

  /// updateContent 策略下,置顶已有窗口前发内容更新事件。
  @protected
  Future<void> onReuseContent(WindowController controller) async {}

  /// 子窗口 ready 后的补发钩子。
  @protected
  Future<void> onSubWindowReady(int windowId) async {}

  /// 额外注册的 manager 侧事件 handler。
  @protected
  Map<String, Future<dynamic> Function(dynamic)> get managerHandlers =>
      const {};

  /// createWindow 成功后、setFrame 之前的钩子(通话记录创建上下文)。
  @protected
  void onWindowCreated(WindowController controller) {}

  /// 窗口关闭状态清理后的钩子(媒体预览清 pending show)。
  @protected
  void onSubWindowClosed() {}

  // -------------------------------------------------------------- 基类状态

  WindowController? _windowController;
  bool _windowReady = false;
  bool _handlersInstalled = false;

  @protected
  WindowController? get windowController => _windowController;

  @protected
  bool get windowReady => _windowReady;

  int? get windowId => _windowController?.windowId;

  bool get isReady => _windowController != null && _windowReady;

  @protected
  void clearWindowState() {
    _windowController = null;
    _windowReady = false;
  }

  // -------------------------------------------------------------- 创建序列

  /// 统一创建序列:createPayload + 注入 kind/_selfUserId → createWindow →
  /// setFrame → center → show。
  /// 必须先 center 再 show:插件创建的 NSWindow 初始位于屏幕原点(macOS 为
  /// 左下角),先 show 会在角落闪现一帧后才跳到屏幕中央。
  @protected
  Future<WindowController> createAndShow() async {
    final payload = createPayload();
    payload[kWindowKindKey] = creationWindowKind;
    if (injectSelfUserId) {
      payload['_selfUserId'] = Imclient.currentUserId;
    }

    final WindowController created;
    try {
      created = await DesktopMultiWindow.createWindow(jsonEncode(payload));
    } catch (e) {
      debugPrint('$windowKind createWindow failed: $e');
      rethrow;
    }
    _windowController = created;
    _windowReady = false;
    onWindowCreated(created);

    // 先定尺寸并显示(子窗口 window_manager 初始化依赖已挂载的 NSWindow),
    // 标题、最小尺寸等样式由子窗口按自身 locale 设置。
    final size = initialWindowSize();
    await created.setFrame(Rect.fromLTWH(0, 0, size.width, size.height));
    await created.center();
    await created.show();
    return created;
  }

  // -------------------------------------------------------------- 复用

  /// 复用已存在窗口。返回 true 表示已处理完毕(不再创建新窗口);
  /// 返回 false 表示窗口不存在或已失效,调用方继续走创建流程。
  /// 默认实现按 [reusePolicy]:raiseOnly 仅置顶;updateContent 先
  /// [onReuseContent] 再置顶;recreate 关闭旧窗口后返回 false。
  /// 失效(show 抛异常)时清状态并返回 false,与原各 Manager 一致。
  @protected
  Future<bool> reuseExistingWindow() async {
    final controller = _windowController;
    if (controller == null) return false;
    if (reusePolicy == SubWindowReusePolicy.recreate) {
      try {
        await controller.close();
      } catch (e) {
        debugPrint('$windowKind close existing window failed: $e');
      }
      clearWindowState();
      onSubWindowClosed();
      return false;
    }
    try {
      if (reusePolicy == SubWindowReusePolicy.updateContent) {
        await onReuseContent(controller);
      }
      await controller.show();
    } catch (e) {
      debugPrint('$windowKind show existing window failed: $e');
      clearWindowState();
    }
    return _windowController != null;
  }

  // -------------------------------------------------------------- 事件

  /// 懒安装事件 handler(幂等)。
  @protected
  void installHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;
    final channel = WindowEventChannel();
    registerManagerHandlers(channel);
    channel.listen();
  }

  /// 注册 ready/closed 与 [managerHandlers];通话的就绪/关闭事件
  /// 由 MainAvEngineKitProxy 路由,覆写本方法为空。
  @protected
  void registerManagerHandlers(WindowEventChannel channel) {
    channel.register('$windowKind.ready', _handleReady);
    channel.register('$windowKind.windowClosed', _handleWindowClosed);
    managerHandlers.forEach(channel.register);
  }

  Future<dynamic> _handleReady(dynamic args) async {
    final windowId = args['windowId'] as int?;
    if (windowId == null || windowId != _windowController?.windowId) {
      return null;
    }
    _windowReady = true;
    await onSubWindowReady(windowId);
    return null;
  }

  Future<dynamic> _handleWindowClosed(dynamic args) async {
    // ESC 主动关窗与系统关闭回调可能各发一次;快速重开时旧窗口迟到的
    // 关闭事件不能清掉新窗口的状态,按 windowId 过滤。
    final windowId = args['windowId'] as int?;
    if (windowId != null &&
        _windowController != null &&
        windowId != _windowController!.windowId) {
      return null;
    }
    clearWindowState();
    onSubWindowClosed();
    return null;
  }

  // -------------------------------------------------------------- 关闭

  /// 关闭子窗口(主窗口主动调用,如搜索窗定位消息跳回主窗口后)。
  Future<void> close() async {
    final controller = _windowController;
    clearWindowState();
    if (controller != null) {
      try {
        await controller.close();
      } catch (e) {
        debugPrint('$windowKind close window failed: $e');
      }
    }
  }
}
