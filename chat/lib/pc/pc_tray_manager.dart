import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:menu_base/menu_base.dart' as mb;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart' as tm;
import 'package:window_manager/window_manager.dart';
import 'package:chat/pc/pc_window_manager.dart';
import 'package:chat/l10n/app_localizations.dart';

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

  /// Windows 下缓存的托盘图标真实文件路径（从 asset 提取的 .ico）。
  String? _trayIconPath;

  /// Windows 下缓存的透明图标真实文件路径（闪烁用）。
  String? _transparentIconPath;

  int get unreadCount => _unreadCount;

  /// 初始化托盘。应在窗口显示后调用。
  Future<void> init() async {
    if (_initialized) {
      return;
    }

    await _prepareIconPaths();
    if (_trayIconPath == null) {
      debugPrint('PCTrayManager: no suitable icon found');
      return;
    }

    try {
      await tm.trayManager.setIcon(_trayIconPath!);
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

  /// 准备托盘图标路径。
  /// Windows 的 tray_manager 插件通过 LoadImage + LR_LOADFROMFILE 加载图标，
  /// 不支持 Flutter asset 路径，也不支持 PNG；必须提取为真实 .ico 文件。
  /// macOS / Linux 可直接使用 asset 路径。
  Future<void> _prepareIconPaths() async {
    if (Platform.isWindows) {
      _trayIconPath = await _extractAssetToTempFile(
          'assets/images/app_icon.ico', 'tray_app_icon.ico');
      _transparentIconPath = await _generateTransparentIco();
    } else if (Platform.isMacOS || Platform.isLinux) {
      // macOS 托盘图标建议为 16x16~22x22 的模板图,这里复用 app_icon
      _trayIconPath = 'assets/images/app_icon.png';
      _transparentIconPath = 'assets/images/transparent.png';
    }
  }

  /// 把 Flutter asset 提取到临时目录，返回真实文件路径。
  Future<String?> _extractAssetToTempFile(
      String assetPath, String fileName) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file.path;
    } catch (e) {
      debugPrint('PCTrayManager extract asset $assetPath failed: $e');
      return null;
    }
  }

  /// 生成 1x1 透明 ICO 文件，供 Windows 托盘闪烁时使用。
  Future<String?> _generateTransparentIco() async {
    try {
      final image = img.Image(width: 1, height: 1);
      image.setPixelRgba(0, 0, 0, 0, 0, 0);
      final icoBytes = img.encodeIco(image);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/tray_transparent.ico');
      await file.writeAsBytes(icoBytes);
      return file.path;
    } catch (e) {
      debugPrint('PCTrayManager generate transparent ico failed: $e');
      return null;
    }
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

  /// 更新托盘未读数展示(macOS 在图标旁显示数字,macOS/Windows 更新 tooltip)。
  /// 未读清零时同时停止闪烁(全部已读)。
  void updateUnreadCount(int count) async {
    _unreadCount = count;
    if (count == 0) {
      _stopFlashing();
    }
    if (!_initialized) {
      // 托盘图标还没建起来(Linux 的 AppIndicator 在 setIcon 时才创建),
      // 这时调 setTitle/setToolTip 只会报错。
      return;
    }
    try {
      final l10n = _l10n;
      final String appTitle = l10n?.appTitle ?? '野火IM';
      if (Platform.isMacOS) {
        await tm.trayManager.setTitle(count > 0 ? '$count' : '');
      }
      // Linux(AppIndicator)没有 tooltip,tray_manager 未实现 setToolTip,
      // 调了只会不断抛 MissingPluginException;改用 label 展示未读数。
      if (Platform.isLinux) {
        await tm.trayManager.setTitle(count > 0 ? '$count' : '');
      } else {
        await tm.trayManager.setToolTip(count > 0
            ? (l10n?.trayUnreadTooltip(count) ?? '$appTitle $count')
            : appTitle);
      }
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
        final iconPath = _flashIconVisible
            ? _trayIconPath
            : _transparentIconPath ?? _trayIconPath;
        if (iconPath != null) {
          await tm.trayManager.setIcon(iconPath);
        }
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
    if (_trayIconPath != null) {
      tm.trayManager.setIcon(_trayIconPath!).catchError((e) {
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
