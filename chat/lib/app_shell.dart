import 'package:flutter/widgets.dart';
import 'package:imclient/imclient_platform.dart';

/// App 形态的三条**正交**轴。
///
/// 早先只有一个 `isDesktopShell`,同时表达了"多栏布局""桌面密度""指针交互"
/// 三件事 —— 在手机和 PC 这两种形态里它们恰好同涨同落,合成一个开关不出问题。
/// 平板打破了这个巧合:它要多栏布局,但要移动端的密度(手指点不准 PC 的热区)
/// 和移动端的交互(没有 hover、没有右键)。所以判断点必须按语义落到下面三条轴上,
/// 不要再问"是不是桌面"。
///
/// | | [isMultiPane] | [isDesktopStyle] | [isPointerInput] |
/// |---|---|---|---|
/// | 手机 | ✗ 单栏 | ✗ 松 | ✗ 触摸 |
/// | PC | ✓ 多栏 | ✓ 密 | ✓ 指针 |
/// | 平板 | 宽时 ✓ | ✗ 松 | ✗ 触摸 |
///
/// 另有两类判断**不属于**这里,不要往三条轴上硬套:
/// - **原生能力**(window_manager/托盘/截图/多窗口/FFI):用
///   [WfcPlatform.isNativeDesktop] —— 鸿蒙电脑是桌面形态但没有这些能力。
/// - **平台实现差异**(SDK 能力、通道走向、上报给服务端的字段、选哪套原生 API):
///   与 UI 无关,直接用 [WfcPlatform.isDesktop]。例如备份包的 appType、
///   桌面 WebView 的 UA 标记、通话走不走子窗口代理。
///
/// 完整背景见仓库根目录 PAD_ADAPTATION_PLAN.md。
class AppShell {
  AppShell._();

  /// 平板进入多栏布局的窗口宽度断点(逻辑像素)。
  ///
  /// 720:iPad mini 竖屏 744pt 刚好进两栏;iPad 1/3 分屏(320~375)自动回落单栏。
  static const double multiPaneBreakpoint = 720;

  /// 多栏布局:列表与详情同屏,详情在右栏内打开(而不是整页 push)。
  ///
  /// 平板这一档取决于**运行时窗口宽度**而不是平台 —— 旋转、分屏、台前调度、折叠屏
  /// 都会让同一进程内的宽度来回跳,所以这里读 MediaQuery,调用方会跟着重建。
  /// `sizeOf` 是按 size 这一维订阅的,键盘弹出(viewInsets 变化)不会触发重建。
  ///
  /// 手机与 PC 不碰 MediaQuery:两者的形态是平台常量,不建立多余的重建依赖。
  static bool isMultiPane(BuildContext context) {
    if (WfcPlatform.isTablet) {
      return MediaQuery.sizeOf(context).width >= multiPaneBreakpoint;
    }
    return WfcPlatform.isDesktop;
  }

  /// 桌面视觉与产品形态:更密的行高/留白/字号,桌面专属配色与头部栏
  /// (chatBgDesktop、[PcPageHeader] 等),以及只在桌面出现的页面(如扫码登录页)。
  ///
  /// 平板为 false —— 触控热区不能跟着桌面缩到 32~40,视觉与页面形态都沿用移动端
  /// 那一套。它是三条轴里最"宽"的一条,判断点数量最多;拆轴的价值在于把布局与
  /// 交互这两类从这堆里择出来,让平板只翻它该翻的那部分。
  static bool get isDesktopStyle => WfcPlatform.isDesktop;

  /// 指针交互:hover 反馈、鼠标指针形状、右键菜单、键盘快捷键、Enter 发送、
  /// 列表选中态常驻高亮。
  ///
  /// 平板为 false。iPadOS 可以外接键鼠,但那是"额外能力"而不是"默认交互模型",
  /// 界面不能预先按指针来排(见 PAD_ADAPTATION_PLAN.md 阶段 4)。
  static bool get isPointerInput => WfcPlatform.isDesktop;
}
