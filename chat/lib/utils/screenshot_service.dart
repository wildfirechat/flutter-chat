import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import 'package:chat/l10n/app_localizations.dart';

/// 截图结果
class ScreenshotResult {
  /// 截图保存路径；成功时非空
  final String? path;

  /// 失败原因；失败时非空。用户取消时 error 为 null。
  final String? error;

  bool get success => path != null;

  ScreenshotResult._({this.path, this.error});

  factory ScreenshotResult.success(String path) => ScreenshotResult._(path: path);

  factory ScreenshotResult.failure(String error) => ScreenshotResult._(error: error);
}

/// 桌面端通过调用独立的 flameshot 进程完成截图。
///
/// 需要把对应平台的 flameshot 二进制放到 native_tools 目录：
/// - Windows: native_tools/windows/flameshot/bin/flameshot.exe
///            （cmake --install / 官方 portable 包的 bin/include/lib 安装树，只取 bin/）
/// - Linux:   native_tools/linux/flameshot/<arch>/squashfs-root/usr/bin/flameshot
///            （`flameshot.AppImage --appimage-extract` 的原始产物；
///            bin/ 下的 qt.conf 靠与 plugins/ 的兄弟关系定位 Qt 平台插件）
///            支持的 <arch>: x86_64, arm64，由 CMake 按目标架构选择。
/// - macOS:   native_tools/macos/flameshot.app
///
/// 这些目录由各平台构建脚本（CMake / Xcode）复制到最终 app bundle。
class ScreenshotService {
  static String? _toolDir;

  /// 当前平台是否具备截图工具。
  static Future<bool> get isAvailable async {
    final bin = await _resolveBinaryPath();
    return bin != null && File(bin).existsSync();
  }

  /// 调用 flameshot GUI，返回 [ScreenshotResult]。
  /// 用户取消会返回 path 为 null、error 为 null 的结果。
  static Future<ScreenshotResult> captureToFile(AppLocalizations l10n) async {
    final tmpDir = Directory.systemTemp;
    final out = p.join(
      tmpDir.path,
      'chat_shot_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    await _hideWindow();
    try {
      final result = await _runFlameshot(
        subcommand: 'gui',
        args: ['--path', out],
      );

      // flameshot 退出码：
      // 0 = 截图成功；2 = 用户取消/中断；其他 = 异常。
      if (result.exitCode == 2) {
        return ScreenshotResult._();
      }

      if (result.exitCode != 0) {
        final err = _extractError(result);
        return ScreenshotResult.failure(l10n.screenshotFailed(err));
      }

      final file = File(out);
      if (await file.exists()) {
        return ScreenshotResult.success(out);
      }

      return ScreenshotResult._();
    } on ProcessException catch (e) {
      return ScreenshotResult.failure(l10n.screenshotToolLaunchFailed(e));
    } catch (e) {
      return ScreenshotResult.failure(l10n.screenshotException(e));
    } finally {
      await _showWindow();
    }
  }

  /// 直接读回 PNG 字节，避免落盘。注意大图片会占用内存。
  static Future<Uint8List?> captureToBytes(AppLocalizations l10n) async {
    final result = await captureToFile(l10n);
    if (result.path == null) return null;
    try {
      return await File(result.path!).readAsBytes();
    } catch (e) {
      return null;
    }
  }

  /// 运行 flameshot。
  /// macOS 直接调用 .app 包里的二进制；Windows / Linux 直接调用二进制。
  static Future<ProcessResult> _runFlameshot({
    required String subcommand,
    required List<String> args,
  }) async {
    final bin = await _resolveBinaryPath();
    if (bin == null || !File(bin).existsSync()) {
      return ProcessResult(-1, -1, '', 'flameshot binary not found');
    }

    return Process.run(
      bin,
      [subcommand, ...args],
      workingDirectory: _toolDir,
      environment: Platform.isMacOS ? null : _toolEnv,
      runInShell: false,
    );
  }

  static Future<String?> _resolveBinaryPath() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    if (Platform.isWindows) {
      _toolDir = p.join(exeDir, 'flameshot');
      return p.join(_toolDir!, 'flameshot.exe');
    }

    if (Platform.isLinux) {
      final arch = _linuxArch();
      if (arch == null) return null;
      // 打包产物是 `flameshot.AppImage --appimage-extract` 的原始树，
      // bin/ 下的 qt.conf 靠与 plugins/ 的兄弟关系定位 Qt 平台插件，
      // _toolDir 必须指到 bin/，不能拍平。
      _toolDir = p.join(exeDir, 'flameshot', arch, 'bin');
      return p.join(_toolDir!, 'flameshot');
    }

    if (Platform.isMacOS) {
      final appPath = p.join(exeDir, '..', 'Resources', 'flameshot.app');
      if (!Directory(appPath).existsSync()) return null;
      _toolDir = p.join(appPath, 'Contents', 'MacOS');
      return p.join(_toolDir!, 'flameshot');
    }

    return null;
  }

  /// 把 Dart 的 [Abi] 映射到常用的 Linux 架构目录名。
  static String? _linuxArch() {
    switch (Abi.current()) {
      case Abi.linuxX64:
        return 'x86_64';
      case Abi.linuxArm64:
        return 'arm64';
      case Abi.linuxArm:
        return 'arm';
      case Abi.linuxIA32:
        return 'i386';
      case Abi.linuxRiscv64:
        return 'riscv64';
      default:
        return null;
    }
  }

  static Map<String, String> get _toolEnv {
    final env = Map<String, String>.from(Platform.environment);
    if (Platform.isLinux && _toolDir != null) {
      // _toolDir 是 bin/，.so 依赖在其兄弟目录 lib/ 下。
      final libDir = p.join(p.dirname(_toolDir!), 'lib');
      final old = env['LD_LIBRARY_PATH'] ?? '';
      env['LD_LIBRARY_PATH'] = old.isEmpty ? libDir : '$libDir:$old';
    }
    if (Platform.isWindows && _toolDir != null) {
      final old = env['PATH'] ?? '';
      env['PATH'] = old.isEmpty ? _toolDir! : '${_toolDir!};$old';
    }
    return env;
  }

  static Future<void> _hideWindow() async {
    // macOS 上隐藏主窗口可能导致子进程无法获得屏幕录制权限或窗口焦点，
    // 因此仅对 Windows/Linux 做隐藏处理；macOS 上保持窗口可见。
    if (Platform.isWindows || Platform.isLinux) {
      try {
        await windowManager.hide();
      } catch (e) {
        // window_manager 未初始化时忽略
      }
    }
  }

  static Future<void> _showWindow() async {
    if (Platform.isWindows || Platform.isLinux) {
      try {
        await windowManager.show();
        await windowManager.focus();
      } catch (e) {
        // ignore
      }
    }
  }

  static String _extractError(ProcessResult result) {
    final stderr = result.stderr?.toString().trim() ?? '';
    final stdout = result.stdout?.toString().trim() ?? '';
    if (stderr.isNotEmpty) return stderr;
    if (stdout.isNotEmpty) return stdout;
    return 'exit code ${result.exitCode}';
  }
}
