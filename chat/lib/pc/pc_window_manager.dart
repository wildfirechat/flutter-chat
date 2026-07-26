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
/// 负责：最小尺寸限制、启动尺寸/位置记忆、最大化状态恢复、
/// 关闭事件拦截（供托盘使用）。
class PCWindowManager {
  static const double _minWidth = 900;
  static const double _minHeight = 640;
  static const String _prefsKey = 'pc_window_state';

  static final PCWindowManager _instance = PCWindowManager._internal();
  factory PCWindowManager() => _instance;
  PCWindowManager._internal();

  bool _initialized = false;
  bool _isQuitting = false;
  // 窗口尺寸/位置变化逐帧触发,防抖后的挂起保存定时器。
  Timer? _saveStateTimer;

  /// 是否正在通过托盘/退出流程主动退出应用。
  /// 用于区分"应用关闭导致的 disconnect"和"真正的登出"。
  bool get isQuitting => _isQuitting;

  /// 初始化 window_manager。应在 [WidgetsFlutterBinding.ensureInitialized] 之后、
  /// runApp 之前调用。
  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await windowManager.ensureInitialized();
    // Windows:尽早隐藏系统标题栏(在原生首帧 Show 之前),
    // 改用 Flutter 自绘标题栏(pc/widgets/pc_window_caption.dart),
    // 与 App 内主题保持一致。仅影响主窗口;子窗口不走本类。
    if (Platform.isWindows) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    _initialized = true;
  }

  /// 配置窗口参数。应在 [WidgetsFlutterBinding.ensureInitialized] 之后调用，
  /// 通常在桌面端读取完登录状态后再执行，避免未登录时窗口先闪到上次保存的位置。
  ///
  /// [restoreSavedState] 为 true 时恢复上次记录的窗口大小、位置和最大化状态；
  /// 为 false 时使用默认尺寸并居中显示，常用于未登录时避免窗口先跳到旧位置再变回登录页。
  Future<void> setupWindow({bool restoreSavedState = true}) async {
    if (!_initialized) {
      await ensureInitialized();
    }

    await windowManager.setMinimumSize(const Size(_minWidth, _minHeight));

    if (restoreSavedState) {
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
    } else {
      // 未登录或明确不恢复：使用最小尺寸并居中，避免窗口闪到上次登录时的旧位置
      await windowManager.setSize(const Size(_minWidth, _minHeight));
      await windowManager.center();
    }

    // 阻止默认关闭,交给托盘/应用自己处理
    await windowManager.setPreventClose(true);
    windowManager.addListener(_WindowListener());

    await windowManager.show();
    await windowManager.focus();

    // 窗口显示后初始化托盘(tray_manager 仅原生桌面可用)
    if (WfcPlatform.isNativeDesktop) {
      await PCTrayManager().init();
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
    _saveStateTimer?.cancel();
    _saveStateTimer = Timer(const Duration(milliseconds: 500), _saveWindowState);
  }

  Future<void> _saveWindowState() async {
    // 显式保存(关闭窗口/退出流程)时取消挂起的防抖保存,避免重复写盘。
    _saveStateTimer?.cancel();
    _saveStateTimer = null;
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
          ? Offset((json['left'] as num).toDouble(), (json['top'] as num).toDouble())
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
