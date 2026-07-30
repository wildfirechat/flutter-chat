import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/imclient_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:chat/pc/pc_tray_manager.dart';

GlobalKey<NavigatorState>? _navKey;

void setPCWindowNavKey(GlobalKey<NavigatorState> key) {
  _navKey = key;
}

GlobalKey<NavigatorState>? get pcWindowNavKey => _navKey;

/// 桌面端应用是否处于“后台”（窗口隐藏/最小化/关闭到托盘）。
/// 供 [MyApp] 的未读消息监听使用，替代手机端的生命周期回调。
final ValueNotifier<bool> pcAppInBackground = ValueNotifier<bool>(false);

/// 桌面端窗口管理辅助类。
/// 负责：登录页/主界面两套窗口形态、最小尺寸限制、启动尺寸/位置记忆、
/// 最大化状态恢复、关闭事件拦截（供托盘使用）。
class PCWindowManager {
  static const double _minWidth = 900;
  static const double _minHeight = 640;

  /// 登录页窗口尺寸。按常见 PC IM 的做法收成固定小窗，尺寸贴着登录页内容
  /// （二维码 220 + 标题/提示/切换入口，四周 32/24 内边距）来定，内容铺满整窗。
  static const double _loginWidth = 400;
  static const double _loginHeight = 500;

  /// Linux 运行时用系统 GtkHeaderBar 当标题栏(见 linux/runner/my_application.cc),
  /// 它的高度算在 window_manager 报的窗口尺寸内、却不进 Flutter 画布——留给内容的
  /// 高度会比 Windows/macOS(标题栏是 Flutter 里自绘/沉浸式,不占额外原生空间)少
  /// 一截,不加高的话登录页最下面的切换按钮出不来,要靠滚动才能看到。
  static const double _linuxHeaderBarExtra = 56;

  Size get _loginWindowSize => Size(
        _loginWidth,
        _loginHeight + (WfcPlatform.isLinux ? _linuxHeaderBarExtra : 0),
      );

  /// 回到主界面时用来解除登录页的最大尺寸限制。Windows 端 `SetMaximumSize`
  /// 直接忽略负值（插件内部 -1 才表示"不限制"，但从 Dart 传不进去），
  /// 只能给一个大于任何显示器的有限值。
  static const Size _unlimitedSize = Size(20000, 20000);

  static const String _prefsKey = 'pc_window_state';

  static final PCWindowManager _instance = PCWindowManager._internal();
  factory PCWindowManager() => _instance;
  PCWindowManager._internal();

  bool _initialized = false;
  bool _isQuitting = false;
  // 当前是否处于登录页的小窗形态。此形态下不保存窗口状态,避免覆盖主界面记住的尺寸/位置。
  bool _isLoginWindow = false;
  // 窗口尺寸/位置变化逐帧触发,防抖后的挂起保存定时器。
  Timer? _saveStateTimer;

  /// 是否正在通过托盘/退出流程主动退出应用。
  /// 用于区分"应用关闭导致的 disconnect"和"真正的登出"。
  bool get isQuitting => _isQuitting;

  /// 窗口是否处于登录页形态（固定小窗）。
  bool get isLoginWindow => _isLoginWindow;

  /// 鸿蒙电脑也走桌面 Shell,但没有 window_manager 插件,本类整体降级为空实现。
  bool get _available => WfcPlatform.isNativeDesktop;

  /// 初始化 window_manager。应在 [WidgetsFlutterBinding.ensureInitialized] 之后、
  /// runApp 之前调用。
  Future<void> ensureInitialized() async {
    if (_initialized || !_available) {
      return;
    }
    await windowManager.ensureInitialized();
    // Windows:尽早隐藏系统标题栏(在原生首帧 Show 之前),
    // 改用 Flutter 自绘标题栏(pc/widgets/pc_window_caption.dart),
    // 与 App 内主题保持一致。仅影响主窗口;子窗口不走本类。
    if (WfcPlatform.isWindows) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    _initialized = true;
  }

  /// 配置窗口参数。应在 [WidgetsFlutterBinding.ensureInitialized] 之后调用，
  /// 且要等桌面端读完登录状态再执行：窗口在这里才第一次 show，未登录时直接以
  /// 登录页小窗出现，已登录才恢复上次记录的大小/位置/最大化状态，避免窗口先
  /// 闪一下主界面尺寸或上次登录时的旧位置。
  Future<void> setupWindow({required bool isLogined}) async {
    if (!_available) {
      return;
    }
    if (!_initialized) {
      await ensureInitialized();
    }

    if (isLogined) {
      await _applyMainGeometry();
    } else {
      _isLoginWindow = true;
      await _applyLoginGeometry();
    }

    // 阻止默认关闭,交给托盘/应用自己处理
    await windowManager.setPreventClose(true);
    windowManager.addListener(_WindowListener());

    await windowManager.show();
    await windowManager.focus();

    // 窗口显示后初始化托盘
    await PCTrayManager().init();
  }

  /// 切换到登录页窗口形态：固定小窗、居中。
  /// 登出/被踢下线/token 失效回到登录页时调用（由 PCQRLoginScreen 统一触发），
  /// 启动时未登录则由 [setupWindow] 直接进入这一形态。重复调用无副作用。
  Future<void> applyLoginWindow() async {
    if (!_available || _isLoginWindow) {
      return;
    }
    if (!_initialized) {
      await ensureInitialized();
    }
    // 切走前把主界面最后的尺寸/位置落盘(防抖里可能还挂着一次)。
    // 置位之后 _saveWindowState 就被登录态挡住了。
    await _saveWindowState();
    _isLoginWindow = true;
    await _applyLoginGeometry();
  }

  /// 切换回主界面窗口形态：解除登录页的固定尺寸，恢复上次记住的大小/位置/最大化状态。
  /// 登录成功时调用（MyApp.onLoginSuccess，二维码与验证码/密码两条登录链路都会经过）。
  Future<void> applyMainWindow() async {
    if (!_available || !_isLoginWindow) {
      return;
    }
    if (!_initialized) {
      await ensureInitialized();
    }
    _isLoginWindow = false;
    await _applyMainGeometry();
  }

  Future<void> _applyLoginGeometry() async {
    final size = _loginWindowSize;
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    }
    // min == max 是三端通用的"钉死尺寸"手段:Windows 的 WM_GETMINMAXINFO、
    // macOS 的 min/maxSize、Linux 的 geometry hints 都吃这一对。
    await windowManager.setMinimumSize(size);
    await windowManager.setMaximumSize(size);
    await windowManager.setSize(size);
    await windowManager.center();
    // 再去掉缩放边框,免得登录窗边缘还出现缩放光标。
    // Linux 不动 resizable:GTK 的不可缩放窗口改按子控件的自然尺寸走,会丢掉上面设的尺寸;
    // 且 Linux 端 setMaximizable(false) 实为改 type hint 成 DIALOG,副作用更大,一并跳过。
    if (WfcPlatform.isWindows || WfcPlatform.isMacOS) {
      await windowManager.setResizable(false);
    }
    if (WfcPlatform.isWindows) {
      await windowManager.setMaximizable(false);
    }
  }

  Future<void> _applyMainGeometry() async {
    if (WfcPlatform.isWindows || WfcPlatform.isMacOS) {
      await windowManager.setResizable(true);
    }
    if (WfcPlatform.isWindows) {
      await windowManager.setMaximizable(true);
    }
    await windowManager.setMaximumSize(_unlimitedSize);
    await windowManager.setMinimumSize(const Size(_minWidth, _minHeight));

    final state = await _loadWindowState();
    if (state != null) {
      await windowManager.setSize(state.size);
      if (state.position != null) {
        await windowManager.setPosition(state.position!);
      }
      if (state.isMaximized) {
        await windowManager.maximize();
      }
    } else {
      // 无保存状态:使用最小尺寸并居中
      await windowManager.setSize(const Size(_minWidth, _minHeight));
      await windowManager.center();
    }
  }

  /// 主动请求关闭窗口并退出应用（托盘菜单"退出"使用）。
  Future<void> closeWindow() async {
    _isQuitting = true;
    await _saveWindowState();
    await windowManager.setPreventClose(false);
    await windowManager.close();
    // 先断开 IM 连接,给 1 秒让网络包发出,再强制结束进程。
    await Imclient.disconnect();
    await Future.delayed(const Duration(seconds: 1));
    exit(0);
  }

  Future<_WindowState?> _loadWindowState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        return null;
      }
      return _WindowState.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      debugPrint('load window state failed: $e');
      return null;
    }
  }

  /// 窗口拖动/缩放期间逐帧回调,防抖 500ms,停止后才真正落盘,避免逐帧磁盘 IO。
  void _scheduleSaveWindowState() {
    if (_isLoginWindow) {
      return;
    }
    _saveStateTimer?.cancel();
    _saveStateTimer =
        Timer(const Duration(milliseconds: 500), _saveWindowState);
  }

  Future<void> _saveWindowState() async {
    // 显式保存(关闭窗口/退出流程)时取消挂起的防抖保存,避免重复写盘。
    _saveStateTimer?.cancel();
    _saveStateTimer = null;
    // 登录页是固定小窗,它的尺寸/位置不能覆盖主界面记住的状态。
    if (_isLoginWindow) {
      return;
    }
    try {
      final isMaximized = await windowManager.isMaximized();
      final prefs = await SharedPreferences.getInstance();

      if (isMaximized) {
        // 最大化时 getBounds 返回的是全屏尺寸，直接保存会导致恢复时窗口
        // 占据整个屏幕却不是最大化状态。保留之前保存的正常尺寸，只更新最大化标记。
        final jsonStr = prefs.getString(_prefsKey);
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final oldState = _WindowState.fromJson(jsonDecode(jsonStr));
          final state = _WindowState(
            size: oldState.size,
            position: oldState.position,
            isMaximized: true,
          );
          await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
        } else {
          // 首次最大化且没有历史正常尺寸，用最小尺寸作为兜底
          final state = _WindowState(
            size: const Size(_minWidth, _minHeight),
            position: null,
            isMaximized: true,
          );
          await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
        }
        return;
      }

      final bounds = await windowManager.getBounds();
      final state = _WindowState(
        size: bounds.size,
        position: bounds.topLeft,
        isMaximized: false,
      );
      await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
    } catch (e) {
      debugPrint('save window state failed: $e');
    }
  }
}

class _WindowState {
  final Size size;
  final Offset? position;
  final bool isMaximized;

  _WindowState({required this.size, this.position, required this.isMaximized});

  factory _WindowState.fromJson(Map<String, dynamic> json) {
    return _WindowState(
      size: Size(
        (json['width'] as num?)?.toDouble() ?? 1280,
        (json['height'] as num?)?.toDouble() ?? 720,
      ),
      position: json['left'] != null && json['top'] != null
          ? Offset(
              (json['left'] as num).toDouble(), (json['top'] as num).toDouble())
          : null,
      isMaximized: json['maximized'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'width': max(size.width, 900),
      'height': max(size.height, 640),
      if (position != null) 'left': position!.dx,
      if (position != null) 'top': position!.dy,
      'maximized': isMaximized,
    };
  }
}

class _WindowListener extends WindowListener {
  void _setBackground(bool value) {
    if (pcAppInBackground.value != value) {
      pcAppInBackground.value = value;
    }
  }

  @override
  void onWindowClose() async {
    if (PCWindowManager().isQuitting) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final closeToExit = prefs.getBool('pc_close_to_exit') ?? false;

    if (closeToExit) {
      // 设置"点击关闭按钮退出应用"时,走完整退出流程(含 disconnect)
      await PCWindowManager().closeWindow();
    } else {
      // 默认行为:先保存窗口状态,然后隐藏窗口(托盘接管)。
      await PCWindowManager()._saveWindowState();
      await windowManager.hide();
      _setBackground(true);
    }
  }

  @override
  void onWindowFocus() {
    _setBackground(false);
  }

  @override
  void onWindowBlur() {
    _setBackground(true);
  }

  @override
  void onWindowMinimize() {
    _setBackground(true);
  }

  @override
  void onWindowRestore() {
    _setBackground(false);
  }

  @override
  void onWindowResized() {
    PCWindowManager()._scheduleSaveWindowState();
  }

  @override
  void onWindowMoved() {
    PCWindowManager()._scheduleSaveWindowState();
  }
}
