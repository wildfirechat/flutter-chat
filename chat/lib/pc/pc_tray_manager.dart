import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:menu_base/menu_base.dart' as mb;
import 'package:tray_manager/tray_manager.dart' as tm;
import 'package:window_manager/window_manager.dart';
import 'package:chat/pc/pc_window_manager.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 桌面端托盘管理。
/// - 托盘图标与菜单、点击托盘显示窗口;
/// - 未读数展示在 title(macOS)/tooltip,由 [updateUnreadCount] 维护;
/// - 闪烁只表示“后台期间有新消息”([notifyNewMessage] 触发),
///   窗口回到前台或未读清零即停止,与未读数本身解耦。
class PCTrayManager {
  static final PCTrayManager _instance = PCTrayManager._internal();
  factory PCTrayManager() => _instance;
  PCTrayManager._internal();

  bool _initialized = false;
  int _unreadCount = 0;
  Timer? _flashTimer;
  bool _flashIconVisible = true;
  tm.TrayListener? _listener;

  int get unreadCount => _unreadCount;

  /// 初始化托盘。应在窗口显示后调用。
  Future<void> init() async {
    if (_initialized) {
      return;
    }

    final iconPath = _detectTrayIcon();
    if (iconPath == null) {
      debugPrint('PCTrayManager: no suitable icon found');
      return;
    }

    try {
      await tm.trayManager.setIcon(iconPath);
      await _setContextMenu();
      _listener = _TrayListener();
      tm.trayManager.addListener(_listener!);
      // 窗口回到前台即停止闪烁(用户已看到消息入口)
      pcAppInBackground.addListener(_onAppBackgroundChanged);
      _initialized = true;
    } catch (e) {
      debugPrint('PCTrayManager init failed: $e');
    }
  }

  void _onAppBackgroundChanged() {
    if (!pcAppInBackground.value) {
      _stopFlashing();
    }
  }

  String? _detectTrayIcon() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // macOS 托盘图标建议为 16x16~22x22 的模板图,这里复用 app_icon
      return 'assets/images/app_icon.png';
    }
    return null;
  }

  Future<void> _setContextMenu() async {
    final l10n = _l10n;
    final menu = mb.Menu(items: [
      mb.MenuItem(
          label: l10n?.showWindow ?? '显示窗口', onClick: (_) => _showWindow()),
      mb.MenuItem.separator(),
      mb.MenuItem(label: l10n?.exit ?? '退出', onClick: (_) => _quitApp()),
    ]);
    await tm.trayManager.setContextMenu(menu);
  }

  AppLocalizations? get _l10n {
    final ctx = pcWindowNavKey?.currentContext;
    if (ctx == null) return null;
    try {
      return AppLocalizations.of(ctx);
    } catch (_) {
      return null;
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quitApp() async {
    await destroy();
    await PCWindowManager().closeWindow();
  }

  /// 更新托盘未读数展示(macOS 在图标旁显示数字,全平台更新 tooltip)。
  /// 未读清零时同时停止闪烁(全部已读)。
  void updateUnreadCount(int count) async {
    _unreadCount = count;
    if (count == 0) {
      _stopFlashing();
    }
    try {
      if (Platform.isMacOS) {
        await tm.trayManager.setTitle(count > 0 ? '$count' : '');
      }
      final l10n = _l10n;
      final String appTitle = l10n?.appTitle ?? '野火IM';
      await tm.trayManager.setToolTip(count > 0
          ? (l10n?.trayUnreadTooltip(count) ?? '$appTitle $count')
          : appTitle);
    } catch (e) {
      debugPrint('PCTrayManager update title/tooltip failed: $e');
    }
  }

  /// 后台收到需提醒的新消息时调用:开始闪烁,直到窗口回到前台或未读清零。
  /// 前台收到消息不闪(用户正看着窗口)。
  void notifyNewMessage() {
    if (!_initialized || !pcAppInBackground.value || _flashTimer != null) {
      return;
    }
    _startFlashing();
  }

  void _startFlashing() {
    _flashIconVisible = true;
    _flashTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      _flashIconVisible = !_flashIconVisible;
      try {
        // 与透明占位图交替实现闪烁;title 数字由 updateUnreadCount 单独维护
        await tm.trayManager.setIcon(_flashIconVisible
            ? _detectTrayIcon()!
            : 'assets/images/transparent.png');
      } catch (e) {
        debugPrint('PCTrayManager flash failed: $e');
      }
    });
  }

  void _stopFlashing() {
    if (_flashTimer == null) {
      return;
    }
    _flashTimer!.cancel();
    _flashTimer = null;
    _flashIconVisible = true;
    final iconPath = _detectTrayIcon();
    if (iconPath != null) {
      tm.trayManager.setIcon(iconPath).catchError((e) {
        debugPrint('PCTrayManager restore icon failed: $e');
      });
    }
  }

  /// 销毁托盘。应用退出前调用。
  Future<void> destroy() async {
    if (!_initialized) {
      return;
    }
    _stopFlashing();
    pcAppInBackground.removeListener(_onAppBackgroundChanged);
    if (_listener != null) {
      tm.trayManager.removeListener(_listener!);
      _listener = null;
    }
    await tm.trayManager.destroy();
    _initialized = false;
  }
}

class _TrayListener extends tm.TrayListener {
  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    tm.trayManager.popUpContextMenu();
  }
}
