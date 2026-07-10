import 'package:flutter/material.dart';

import 'package:chat/app_theme.dart';
import 'package:chat/theme/app_colors.dart';

/// 桌面端设计令牌,布局骨架参照微信 PC:
/// 三段纵深(侧栏 → 列表栏 → 聊天区)建立空间层次,
/// 主色只出现在少数关键位置(选中 tab、发送按钮、光标/选区),
/// 己方气泡用配套色,其余全部灰阶 + 发丝线。
///
/// 这里只放**尺寸**。颜色统一在 [AppColors],经 `context.colors` 取值 ——
/// 明暗两套主题的色值不可能是编译期常量,写在这里就没法跟着主题切换。
class PcTheme {
  PcTheme._();

  // ---- 布局尺寸 ----
  // 60: 参照微信宽度更小的侧栏设计
  static const double sideBarWidth = 60;
  static const double headerHeight = 60;
  static const double conversationCellHeight = 64;

  /// macOS 隐藏标题栏后红绿灯悬浮在侧栏顶部,首个元素需要下移避让。
  static const double sidebarTopInsetMac = 40;

  /// 侧栏纵向节奏。tab 自身是 38×38(图标 22 + 8 内边距),故这里的值再叠加 8 才是视觉间距。
  /// “会话/联系人”与“文件/收藏/工作台/发现”用组间留白区分,不画分隔线。
  static const double sidebarAvatarGap = 24;
  static const double sidebarTabGap = 12;
  static const double sidebarGroupGap = 24;
  static const double sidebarBottomInset = 16;

  /// 搜索浮层比中栏宽出的部分:结果卡片越过中栏、少量悬在右栏之上(微信形态)。
  static const double searchPanelOverhang = 40;

  // ---- 可拖拽尺寸 ----
  // 中栏宽度与输入栏高度可由用户拖拽调整,运行时值取自 PcLayoutViewModel,
  // 这里只给默认值与边界:上界不让一侧把另一侧挤没,下界保证内容仍可读。
  static const double middleColumnDefaultWidth = 298;
  static const double middleColumnMinWidth = 220;
  static const double middleColumnMaxWidth = 420;

  static const double inputBarDefaultHeight = 148;

  /// 无引用条时的下界。挂着引用条时输入栏再抬高一个引用条的高度,
  /// 取 110 是为了让“默认高度 + 引用条”恰好等于 [inputBarDefaultHeight],
  /// 引用消息时输入栏不会跳一下。
  static const double inputBarMinHeight = 110;
  static const double inputBarMaxHeight = 480;

  /// 输入栏最多占会话区高度的比例:窗口压缩时优先保证消息列表可读。
  static const double inputBarMaxHeightRatio = 0.6;

  /// 分隔条命中区厚度。视觉仍是贴边的 0.5 发丝线,加厚只为好抓。
  static const double resizeHandleThickness = 6;

  // ---- 字号(桌面密度,比移动端小一号) ----
  static TextStyle cellTitle(BuildContext context) => TextStyle(fontSize: 14, color: context.colors.textPrimary);

  static TextStyle cellSubtitle(BuildContext context) => TextStyle(fontSize: 12, color: context.colors.textSecondary);

  static TextStyle cellTime(BuildContext context) => TextStyle(fontSize: 11, color: context.colors.textTertiary);

  static TextStyle paneTitle(BuildContext context) =>
      TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: context.colors.textPrimary);

  /// 桌面子树的 Theme 覆盖:去水波纹、桌面化的菜单/滚动条,
  /// 让复用的移动端二级页在右栏内也保持一致观感。
  ///
  /// 明暗跟随祖先主题(main.dart 的 MaterialApp),这里只做桌面密度/形态的覆盖,
  /// 不再自己决定亮暗。
  static ThemeData themeData(BuildContext context) {
    final base = Theme.of(context);
    final colors = context.colors;
    final isDark = base.brightness == Brightness.dark;
    // 暗色下 hover/highlight 要提白,浅色下压黑。
    final overlay = colors.hoverOverlay;
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: colors.accent, brightness: base.brightness).copyWith(
        primary: colors.accent,
        onPrimary: colors.onAccent,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        error: colors.danger,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: overlay,
      hoverColor: overlay,
      // 桌面统一紧凑密度:复用的移动端页面在 PC 壳内无需再逐 widget 判平台,
      // 需要移动端密度的组件可自行显式覆盖。
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        titleTextStyle: paneTitle(context),
        toolbarHeight: headerHeight,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.popupBg,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: colors.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: TextStyle(fontSize: 13, color: colors.textPrimary),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        textStyle: TextStyle(fontSize: 12, color: isDark ? colors.textPrimary : Colors.white),
        decoration: BoxDecoration(
          color: isDark ? colors.popupBg : const Color(0xCC000000),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => isDark
              ? (states.contains(WidgetState.hovered) ? Colors.white30 : Colors.white24)
              : (states.contains(WidgetState.hovered) ? Colors.black26 : Colors.black12),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accent.withValues(alpha: isDark ? 0.35 : 0.25),
      ),
      // 圆形勾选框全端统一(app_theme.dart),桌面端在此基础上收紧密度
      checkboxTheme: AppTheme.checkboxTheme(colors, base.brightness).copyWith(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      dividerTheme: DividerThemeData(color: colors.hairline, thickness: 0.5, space: 0.5),
    );
  }
}
