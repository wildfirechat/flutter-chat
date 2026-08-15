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
/// 登录后主界面分流到的三种 Shell,由 [AppShell.shellFor] 选出,`AppHome` 据此建树。
///
/// 之所以把选择结果做成一个值而不是就地写三元:三种 Shell 各自都会拉起 IM、
/// 通话引擎和一堆 ViewModel,在测试里 pump 不动,而"哪种设备 + 多宽的窗口 →
/// 哪个 Shell"这条规则恰恰是整个 pad 适配的总闸,必须能被单独钉住。
enum AppShellKind {
  /// 单栏 `HomeTabBar`:手机,以及窄窗口(分屏、竖屏小平板)下的平板。
  singleColumn,

  /// 平板两栏 `PadHome`:左列表 + 右详情。
  padTwoPane,

  /// PC 三栏 `PCHome`。
  pcThreePane,
}

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

  /// 主界面该用哪个 Shell。
  ///
  /// 只有两步:先按 [isMultiPane] 决定单栏还是多栏,多栏再按设备形态分给平板或 PC。
  /// 手机与 PC 的取值与引入平板之前逐位相同 —— 手机 [isMultiPane] 恒 false 走
  /// [AppShellKind.singleColumn],PC 恒 true 且不是平板走
  /// [AppShellKind.pcThreePane],窗口宽度对这两者都不起作用。
  ///
  /// 第二步问的是 [WfcPlatform.isTablet] 而不是 `!isDesktop`:走到这一步时多栏
  /// 只有两种来源 —— 平板够宽,或桌面平台 —— 两个判断在真机上取值必然相同
  /// (桌面三端不查设备形态,恒为 unknown;鸿蒙电脑是 pc 不是 tablet)。用
  /// [WfcPlatform.isTablet] 是因为它直接说明了"两栏是给平板的",而且在桌面宿主
  /// 上跑的单测里也能把平板这条分支走通。
  static AppShellKind shellFor(BuildContext context) {
    if (!isMultiPane(context)) {
      return AppShellKind.singleColumn;
    }
    return WfcPlatform.isTablet
        ? AppShellKind.padTwoPane
        : AppShellKind.pcThreePane;
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
