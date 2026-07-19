import 'package:imclient/imclient_platform.dart';

/// 桌面端(Windows/macOS/Linux/鸿蒙电脑)使用三栏 Shell(PCHome),
/// 移动端(Android/iOS/鸿蒙手机/平板)使用 HomeTabBar。
/// 按平台分流而非按窗口宽度,见 PC_UI_ADAPTATION_PLAN.md 第 1 节。
/// 判断源头已集中到 imclient 的 [WfcPlatform],此处仅保留 UI 语义别名。
bool get isDesktopShell => WfcPlatform.isDesktop;
