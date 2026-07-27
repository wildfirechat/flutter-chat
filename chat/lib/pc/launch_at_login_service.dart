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
/// - Linux：`~/.config/autostart/cn.wildfirechat.chat.flutter.desktop` 文件。
class LaunchAtLoginService {
  LaunchAtLoginService._();

  static const MethodChannel _channel = MethodChannel('chat/launch_at_login');

  /// 与 linux/CMakeLists.txt 的 APPLICATION_ID、Android applicationId 一致。
  static const String _linuxAppId = 'cn.wildfirechat.chat.flutter';
  static const String _desktopFileName = '$_linuxAppId.desktop';

  /// 0.1.1 之前用的文件名。改名后旧文件不会被覆盖，会残留成一条指向已不存在的
  /// 可执行文件（旧名 `chat`）的自启动项，两个入口都要清掉。
  static const String _legacyDesktopFileName = 'chat.desktop';
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
      return _desktopFile().existsSync() || _legacyDesktopFile().existsSync();
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
      final legacyFile = _legacyDesktopFile();
      if (legacyFile.existsSync()) {
        await legacyFile.delete();
      }
      if (enabled) {
        await file.parent.create(recursive: true);
        await file.writeAsString('[Desktop Entry]\n'
            'Type=Application\n'
            'Name=野火IM\n'
            'Icon=$_linuxAppId\n'
            'Exec=${Platform.resolvedExecutable}\n'
            'Terminal=false\n'
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

  static File _desktopFile() => _autostartFile(_desktopFileName);

  static File _legacyDesktopFile() => _autostartFile(_legacyDesktopFileName);

  static File _autostartFile(String fileName) {
    final home = Platform.environment['HOME'] ?? '';
    return File('$home/.config/autostart/$fileName');
  }
}
