import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
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

/// 桌面端截图。macOS 走原生 ScreenCaptureKit(见 Runner/Screenshot/),
/// Windows / Linux 调用独立的 flameshot 进程。
///
/// Windows/Linux 需要把对应平台的 flameshot 二进制放到 native_tools 目录：
/// - Windows: native_tools/windows/flameshot/bin/flameshot.exe
///            （cmake --install / 官方 portable 包的 bin/include/lib 安装树，只取 bin/）
/// - Linux:   native_tools/linux/flameshot/<arch>/squashfs-root/usr/bin/flameshot
///            （`flameshot.AppImage --appimage-extract` 的原始产物；
///            bin/ 下的 qt.conf 靠与 plugins/ 的兄弟关系定位 Qt 平台插件）
///            支持的 <arch>: x86_64, arm64，由 CMake 按目标架构选择。
///
/// 这些目录由各平台构建脚本（CMake / Xcode）复制到最终 app bundle。
class ScreenshotService {
  static const MethodChannel _channel = MethodChannel('chat/screenshot');

  static String? _toolDir;

  /// 当前平台是否具备截图能力。
  static Future<bool> get isAvailable async {
    // macOS 的 ScreenCaptureKit 是系统能力(部署目标 15.0+),始终可用;
    // 屏幕录制权限在 capture 时引导处理。
    if (Platform.isMacOS) return true;
    final bin = await _resolveBinaryPath();
    return bin != null && File(bin).existsSync();
  }

  /// 截图，返回 [ScreenshotResult]。用户取消时 path 与 error 均为 null。
  ///
  /// [hideWindow] 为 true（“隐藏窗口截图”）时：
  /// - macOS：ScreenCaptureKit 截图时排除本 App 全部窗口（无需真的隐藏窗口）；
  /// - Windows/Linux：隐藏主窗口（orderOut,无动画），完成后恢复。
  /// 为 false 时本 App 窗口会出现在截图画面里。
  static Future<ScreenshotResult> captureToFile(AppLocalizations l10n,
      {bool hideWindow = false}) async {
    if (Platform.isMacOS) {
      return _captureMacOS(l10n, excludeSelf: hideWindow);
    }
    return _captureViaFlameshot(l10n, hideWindow: hideWindow);
  }

  /// macOS：经 chat/screenshot 通道调用原生 ScreenCaptureKit 截图。
  /// [excludeSelf] 为 true 时原生侧排除本 App 全部窗口。
  static Future<ScreenshotResult> _captureMacOS(AppLocalizations l10n,
      {bool excludeSelf = false}) async {
    try {
      final result = await _channel
          .invokeMethod<Map>('capture', {'excludeSelf': excludeSelf});
      if (result == null) return ScreenshotResult._();
      if (result['path'] is String) {
        return ScreenshotResult.success(result['path'] as String);
      }
      if (result['error'] is String) {
        return ScreenshotResult.failure(result['error'] as String);
      }
      // cancelled
      return ScreenshotResult._();
    } on PlatformException catch (e) {
      return ScreenshotResult.failure(l10n.screenshotException(e.message ?? '$e'));
    } on MissingPluginException {
      // 原生通道未注册(异常情况),回退 flameshot
      return _captureViaFlameshot(l10n, hideWindow: excludeSelf);
    }
  }

  /// Windows / Linux:调用 flameshot GUI，返回 [ScreenshotResult]。
  /// 用户取消会返回 path 为 null、error 为 null 的结果。
  static Future<ScreenshotResult> _captureViaFlameshot(AppLocalizations l10n,
      {bool hideWindow = false}) async {
    final tmpDir = Directory.systemTemp;
    final out = p.join(
      tmpDir.path,
      'chat_shot_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    if (hideWindow) {
      await _hideWindow();
    }
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
      if (hideWindow) {
        await _restoreWindow();
      }
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
    try {
      // 全平台都用 hide:窗口瞬间消失,没有系统最小化动画(genie 效果
      // 只能系统级关闭,应用无法控制)。flameshot 是独立进程,自己持有
      // 屏幕录制权限,主窗口隐藏不影响它。
      await windowManager.hide();
      // 等窗口服务器真正完成隐藏再启动 flameshot
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      // window_manager 未初始化时忽略
    }
  }

  static Future<void> _restoreWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      // ignore
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
