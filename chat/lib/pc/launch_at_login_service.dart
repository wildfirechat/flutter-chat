import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:win32_registry/win32_registry.dart';

/// PC 端开机自启动（登录后自动打开应用）。
///
/// 三平台实现：
/// - macOS：MethodChannel `chat/launch_at_login`，原生侧用 SMAppService.mainApp
///   （macOS 13+，见 MainFlutterWindow.swift）；
/// - Windows：注册表 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`；
/// - Linux：`~/.config/autostart/chat.desktop` 文件。
class LaunchAtLoginService {
  LaunchAtLoginService._();

  static const MethodChannel _channel = MethodChannel('chat/launch_at_login');
  static const String _desktopFileName = 'chat.desktop';
  static const String _registryValueName = 'chat';
  static const String _runKeyPath =
      r'SOFTWARE\Microsoft\Windows\CurrentVersion\Run';

  static bool get _supported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static Future<bool> isEnabled() async {
    if (!_supported) return false;
    try {
      if (Platform.isMacOS) {
        return await _channel.invokeMethod<bool>('isEnabled') ?? false;
      }
      if (Platform.isWindows) {
        final key = Registry.openPath(RegistryHive.currentUser,
            path: _runKeyPath);
        try {
          return key.getStringValue(_registryValueName) != null;
        } finally {
          key.close();
        }
      }
      return _desktopFile().existsSync();
    } catch (e) {
      debugPrint('LaunchAtLoginService.isEnabled failed: $e');
      return false;
    }
  }

  static Future<bool> setEnabled(bool enabled) async {
    if (!_supported) return false;
    try {
      if (Platform.isMacOS) {
        return await _channel
                .invokeMethod<bool>(enabled ? 'enable' : 'disable') ??
            false;
      }
      if (Platform.isWindows) {
        final key = Registry.openPath(RegistryHive.currentUser,
            path: _runKeyPath,
            desiredAccessRights: AccessRights.allAccess);
        try {
          if (enabled) {
            key.createValue(RegistryValue.string(
                _registryValueName, '"${Platform.resolvedExecutable}"'));
          } else {
            key.deleteValue(_registryValueName);
          }
          return true;
        } finally {
          key.close();
        }
      }
      final file = _desktopFile();
      if (enabled) {
        await file.parent.create(recursive: true);
        await file.writeAsString('[Desktop Entry]\n'
            'Type=Application\n'
            'Name=chat\n'
            'Exec=${Platform.resolvedExecutable}\n'
            'X-GNOME-Autostart-enabled=true\n');
      } else if (file.existsSync()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      debugPrint('LaunchAtLoginService.setEnabled($enabled) failed: $e');
      return false;
    }
  }

  static File _desktopFile() {
    final home = Platform.environment['HOME'] ?? '';
    return File('$home/.config/autostart/$_desktopFileName');
  }
}
