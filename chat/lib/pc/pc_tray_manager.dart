import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:menu_base/menu_base.dart' as mb;
import 'package:tray_manager/tray_manager.dart' as tm;
import 'package:window_manager/window_manager.dart';
import 'package:chat/pc/pc_window_manager.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 桌面端托盘管理。
/// 负责：初始化托盘图标与菜单、点击托盘显示/隐藏窗口、
/// 收到未读消息时闪烁托盘图标并在图标旁显示未读数字。
class PCTrayManager {
  static final PCTrayManager _instance = PCTrayManager._internal();
  factory PCTrayManager() => _instance;
  PCTrayManager._internal();

  bool _initialized = false;
  int _unreadCount = 0;
  bool _isFlashing = false;
  bool _flashIconVisible = true;
  Timer? _flashTimer;

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
      tm.trayManager.addListener(_TrayListener());
      _initialized = true;
    } catch (e) {
      debugPrint('PCTrayManager init failed: \$e');
    }
  }

  String? _detectTrayIcon() {
    if (Platform.isWindows) {
      return 'assets/images/app_icon.png';
    }
    if (Platform.isMacOS) {
      // macOS 托盘图标建议为 16x16~22x22 的模板图,这里复用 app_icon
      return 'assets/images/app_icon.png';
    }
    if (Platform.isLinux) {
      return 'assets/images/app_icon.png';
    }
    return null;
  }

  Future<void> _setContextMenu() async {
    final l10n = _l10n;
    final menu = mb.Menu(items: [
      mb.MenuItem(label: l10n?.open ?? '显示窗口', onClick: (_) => _showWindow()),
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
    // 打开窗口后清除托盘未读状态
    updateUnreadCount(0);
  }

  Future<void> _quitApp() async {
    await PCTrayManager().destroy();
    await PCWindowManager().closeWindow();
  }

  /// 更新托盘未读状态。
  /// macOS 在图标旁显示数字;所有平台有未读时托盘图标闪烁。
  void updateUnreadCount(int count) async {
    _unreadCount = count;
    if (count > 0 && !_isFlashing) {
      _startFlashing();
    } else if (count == 0 && _isFlashing) {
      _stopFlashing();
    }
    try {
      if (Platform.isMacOS) {
        await tm.trayManager.setTitle(count > 0 ? '$count' : '');
      }
      await tm.trayManager.setToolTip(count > 0 ? '野火IM $count 条未读消息' : '野火IM');
    } catch (e) {
      debugPrint('PCTrayManager update title/tooltip failed: \$e');
    }
  }

  void _startFlashing() {
    _isFlashing = true;
    _flashIconVisible = true;
    _flashTimer?.cancel();
    _flashTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      _flashIconVisible = !_flashIconVisible;
      try {
        if (_flashIconVisible) {
          final iconPath = _detectTrayIcon();
          if (iconPath != null) {
            await tm.trayManager.setIcon(iconPath);
          }
        } else {
          // 空图标： macOS 可用透明模板图;Windows/Linux 没有内置透明图标,
          // 先通过置空 title 模拟,实际效果取决于平台。
          // 这里通过设置一个空白 title 占位,保持 title 数字由 updateUnreadCount 单独维护。
          await tm.trayManager.setIcon('assets/images/transparent.png');
        }
      } catch (e) {
        debugPrint('PCTrayManager flash failed: \$e');
      }
    });
  }

  void _stopFlashing() {
    _isFlashing = false;
    _flashTimer?.cancel();
    _flashTimer = null;
    _flashIconVisible = true;
    // 恢复默认图标
    final iconPath = _detectTrayIcon();
    if (iconPath != null) {
      tm.trayManager.setIcon(iconPath).catchError((e) {
        debugPrint('PCTrayManager restore icon failed: \$e');
      });
    }
  }

  /// 销毁托盘。应用退出前调用。
  Future<void> destroy() async {
    if (!_initialized) {
      return;
    }
    _stopFlashing();
    tm.trayManager.removeListener(_TrayListener());
    await tm.trayManager.destroy();
    _initialized = false;
  }
}

class _TrayListener extends tm.TrayListener {
  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
    PCTrayManager().updateUnreadCount(0);
  }

  @override
  void onTrayIconRightMouseDown() {
    tm.trayManager.popUpContextMenu();
  }
}
