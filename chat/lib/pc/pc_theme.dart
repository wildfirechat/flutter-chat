import 'package:flutter/material.dart';

/// 桌面端设计令牌,布局骨架参照微信 PC:
/// 三段灰度纵深(近黑侧栏 → 暖灰列表栏 → 浅灰聊天区)建立空间层次,
/// 品牌蓝 #1F64E4 只出现在少数关键位置(选中 tab、发送按钮、光标/选区),
/// 己方气泡用配套浅蓝,其余全部灰阶 + 发丝线。
/// 所有 PC 端组件的颜色/尺寸从这里取值,禁止散落硬编码。
class PcTheme {
  PcTheme._();

  // ---- 布局尺寸 ----
  // 68 而非 60:macOS 红绿灯按钮区域约 62px 宽,侧栏必须完整容纳
  static const double sideBarWidth = 68;
  static const double middleColumnWidth = 280;
  static const double headerHeight = 60;
  static const double conversationCellHeight = 64;
  static const double inputBarHeight = 148;

  /// macOS 隐藏标题栏后红绿灯悬浮在侧栏顶部,首个元素需要下移避让。
  static const double sidebarTopInsetMac = 40;

  /// 搜索浮层宽度:比中栏宽 40,结果卡片越过中栏、少量悬在右栏之上(微信形态)。
  static const double searchPanelWidth = middleColumnWidth + 40;

  // ---- 品牌色 ----
  static const Color accent = Color(0xFF1F64E4);
  static const Color accentPressed = Color(0xFF1A55C2);
  static const Color badgeRed = Color(0xFFFA5151);

  // ---- 侧栏(近黑) ----
  static const Color sidebarBg = Color(0xFF2E2E2E);
  static const Color sidebarIcon = Color(0xFF8F8F8F);
  static const Color sidebarIconHover = Color(0xFFC9C9C9);

  // ---- 中栏(暖灰列表区) ----
  static const Color middleBg = Color(0xFFE6E5E5);
  static const Color cellHover = Color(0xFFDBDAD9);
  static const Color cellSelected = Color(0xFFC8C7C6);
  static const Color searchFieldBg = Color(0xFFDBDAD9);

  // ---- 右栏(浅灰聊天区) ----
  static const Color chatBg = Color(0xFFF5F5F5);
  static const Color bubbleSent = Color(0xFFD6E4FF); // 品牌蓝的浅色调,黑字可读
  static const Color bubbleReceived = Colors.white;

  // ---- 通用 ----
  static const Color hairline = Color(0xFFDDDCDB);
  static const Color textPrimary = Color(0xFF191919);
  static const Color textSecondary = Color(0xFF7F7F7F);
  static const Color textTertiary = Color(0xFFB2B2B2);

  // ---- 字号(桌面密度,比移动端小一号) ----
  static const TextStyle cellTitle = TextStyle(fontSize: 14, color: textPrimary);
  static const TextStyle cellSubtitle = TextStyle(fontSize: 12, color: textSecondary);
  static const TextStyle cellTime = TextStyle(fontSize: 11, color: textTertiary);
  static const TextStyle paneTitle = TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: textPrimary);

  /// 桌面子树的 Theme 覆盖:去水波纹、绿色主色、桌面化的菜单/滚动条,
  /// 让复用的移动端二级页在右栏内也保持一致观感。
  static ThemeData themeData(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: accent),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.black.withValues(alpha: 0.04),
      hoverColor: Colors.black.withValues(alpha: 0.04),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        titleTextStyle: paneTitle,
        toolbarHeight: headerHeight,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 13, color: textPrimary),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        textStyle: const TextStyle(fontSize: 12, color: Colors.white),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) ? Colors.black26 : Colors.black12,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.25),
      ),
      // 圆形勾选框(微信风格),选中品牌蓝
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: const BorderSide(color: Color(0xFFC0C0C0), width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      dividerTheme: const DividerThemeData(color: hairline, thickness: 0.5, space: 0.5),
    );
  }
}
