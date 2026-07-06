import 'dart:io';

/// 桌面端使用三栏 Shell(PCHome),移动端(Android/iOS/ohos)使用 HomeTabBar。
/// 按平台分流而非按窗口宽度,见 PC_UI_ADAPTATION_PLAN.md 第 1 节。
bool get isDesktopShell => Platform.isWindows || Platform.isMacOS || Platform.isLinux;
