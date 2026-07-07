import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:chat/pc/pc_platform.dart';
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

  /// 初始化 window_manager。应在 [WidgetsFlutterBinding.ensureInitialized] 之后、
  /// runApp 之前调用。
  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await windowManager.ensureInitialized();
    _initialized = true;
  }

  /// 配置窗口参数。应在 App 首帧构建完成后调用（如 MyApp.initState 或首页 initState）。
  Future<void> setupWindow() async {
    if (!_initialized) {
      await ensureInitialized();
    }

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
      // 首次启动:默认 1280x720,居中
      await windowManager.setSize(const Size(1280, 720));
      await windowManager.center();
    }

    // 阻止默认关闭,交给托盘/应用自己处理
    await windowManager.setPreventClose(true);
    windowManager.addListener(_WindowListener());

    await windowManager.show();
    await windowManager.focus();

    // 窗口显示后初始化托盘
    if (isDesktopShell) {
      await PCTrayManager().init();
    }
  }

  /// 主动请求关闭窗口（退出应用时使用）。
  Future<void> closeWindow() async {
    await _saveWindowState();
    await windowManager.setPreventClose(false);
    await windowManager.close();
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
      debugPrint('load window state failed: \$e');
      return null;
    }
  }

  Future<void> _saveWindowState() async {
    try {
      final bounds = await windowManager.getBounds();
      final isMaximized = await windowManager.isMaximized();
      final state = _WindowState(
        size: bounds.size,
        position: bounds.topLeft,
        isMaximized: isMaximized,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
    } catch (e) {
      debugPrint('save window state failed: \$e');
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
    // 默认行为:先保存窗口状态,然后隐藏窗口(托盘接管)。
    // 真正退出由托盘菜单或 Cmd+Q/Alt+F4 处理。
    await PCWindowManager()._saveWindowState();
    await windowManager.hide();
    _setBackground(true);
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
  void onWindowResized() async {
    await PCWindowManager()._saveWindowState();
  }

  @override
  void onWindowMoved() async {
    await PCWindowManager()._saveWindowState();
  }
}
