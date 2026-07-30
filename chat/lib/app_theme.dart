import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chat/pc/pc_platform.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

/// 全端共享的 ThemeData(移动端 + 桌面端通用)。
/// 颜色一律从 [AppColors] 取,桌面端布局/密度的专属覆盖在 pc/pc_theme.dart。
class AppTheme {
  AppTheme._();

  /// ThemeData 不可变,且 `ColorScheme.fromSeed` 每次都要跑一遍 HCT 色彩推导,
  /// 各建一次缓存起来,不要在 build 里反复构造。
  static final ThemeData _light = _buildLight();
  static final ThemeData _dark = _buildDark();

  static ThemeData light() => _light;

  static ThemeData dark() => _dark;

  /// 浅色主题。把关键槽位钉到 [AppColors.light] 的蓝色与中性白灰,
  /// 参考 PC 端配色方案优化,避免 Material 3 默认的蓝紫色调。
  static ThemeData _buildLight() {
    const colors = AppColors.light;
    final base = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: Brightness.light,
      ).copyWith(
        primary: colors.accent,
        onPrimary: colors.onAccent,
        // FilledButton.tonal(次要按钮)的灰底/前景,见「按钮基线」。
        secondaryContainer: colors.buttonSecondaryBg,
        onSecondaryContainer: colors.textPrimary,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        error: colors.danger,
      ),
    );
    return _withColors(base, colors).copyWith(
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: colors.cellTop,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        systemOverlayStyle: systemOverlayStyle(Brightness.light),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accent.withValues(alpha: 0.35),
        selectionHandleColor: colors.accent,
      ),
    );
  }

  /// 暗色主题。Material 的暗色默认值带蓝紫色调(surface tint),这里把关键槽位
  /// 全部钉到 [AppColors.dark] 的中性灰,与 vue-pc-chat 的面板色一致。
  static ThemeData _buildDark() {
    const colors = AppColors.dark;
    final base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: colors.accent,
        onPrimary: colors.onAccent,
        // FilledButton.tonal(次要按钮)的灰底/前景,见「按钮基线」。
        secondaryContainer: colors.buttonSecondaryBg,
        onSecondaryContainer: colors.textPrimary,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        error: colors.danger,
      ),
    );
    return _withColors(base, colors).copyWith(
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: colors.cellTop,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        systemOverlayStyle: systemOverlayStyle(Brightness.dark),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accent.withValues(alpha: 0.35),
        selectionHandleColor: colors.accent,
      ),
    );
  }

  static ThemeData _withColors(ThemeData base, AppColors colors) =>
      base.copyWith(
        extensions: <ThemeExtension<dynamic>>[colors],
        // ---- 分割线基线 ----
        // 列表行间线全端统一:hairlineSoft、0.5 粗、0.5 占位,裸 `const Divider()`
        // 即标准形态,调用点不要再传 color/thickness;内容对齐传 indent,
        // 需要留白的场景显式传 height(例如气泡内 Divider(height: 16))。
        // hairline 留给结构边界(header 下边线、栏间分隔),用 Border/VerticalDivider 画。
        dividerTheme: DividerThemeData(
            color: colors.hairlineSoft, thickness: 0.5, space: 0.5),
        checkboxTheme: checkboxTheme(colors, base.brightness),
        switchTheme: switchTheme(colors, base.brightness),
        filledButtonTheme: FilledButtonThemeData(style: buttonShapeStyle()),
        textButtonTheme: TextButtonThemeData(style: textButtonStyle()),
        // 过渡兜底:repo 内已无 ElevatedButton / OutlinedButton 调用点,这两支只防
        // 新代码或第三方误用时观感失控 —— Elevated 等价 FilledButton(实底 accent、
        // 无阴影),Outlined 等价 FilledButton.tonal(无边框灰底)。
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: buttonShapeStyle().merge(ElevatedButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: colors.onAccent,
            elevation: 0,
            shadowColor: Colors.transparent,
          )),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: buttonShapeStyle().merge(OutlinedButton.styleFrom(
            backgroundColor: colors.buttonSecondaryBg,
            foregroundColor: colors.textPrimary,
            side: BorderSide.none,
          )),
        ),
      );

  // ---- 按钮基线 ----
  //
  // 语义与控件的对应关系,调用点凭裸控件即可得到正确观感,不要再写散落的 styleFrom:
  // - 实底主行动 → FilledButton(危险操作只覆盖 backgroundColor: colors.danger)
  // - 次要动作 → FilledButton.tonal,灰底无边框(危险操作只覆盖 foregroundColor:
  //   colors.danger,不描边 —— 形状只编码层级,颜色只编码语义)
  // - 文字动作(对话框确认位、链接式) → TextButton;对话框「取消」位叠 [mutedTextButtonStyle]
  // - 整页唯一主行动 / 通栏 CTA → 在裸控件上叠 [largeButtonStyle]
  //
  // 颜色不写进按钮主题:FilledButton 与 FilledButton.tonal 共享同一个
  // FilledButtonTheme(SDK 的 themeStyleOf 对两个变体返回同一支 style),在主题里写死
  // backgroundColor 会把 tonal 也染成 accent。颜色钉在 colorScheme 上:
  // primary/onPrimary → 主行动实底,secondaryContainer/onSecondaryContainer → 次要灰底。
  // 禁用态是 M3 默认灰(onSurface 的 12%/38%),两个变体共用;按钮内的 busy spinner
  // 别再传 onAccent —— 禁用灰底上白圈看不见,用 CircularProgressIndicator 默认主色。
  //
  // 尺寸分两档,默认是「中档」(行内、列表行、对话框 footer 的最高频尺寸),
  // 通栏/整页场景显式叠大档 —— 让例外显式化,不让最大号当默认。
  //
  // 形态按平台分叉在这里(而不是 pc_theme):PC 登录窗、根导航对话框都在
  // PcTheme.themeData 子树之外,只有挂在 MaterialApp 主题上才能全覆盖;
  // PcTheme.themeData 是 base.copyWith,会自动继承这里的桌面形态。
  //
  // ⚠️ 桌面数值看着偏大不是笔误:desktop 平台的默认 visualDensity 就是 compact,
  // 渲染时最小高度与纵向 padding 各再减 8,中档的 40 实际落在 ~32(与重构前
  // PcDialog 底栏的按钮等高)。

  /// 实底/灰底按钮共用的「中档」形态(尺寸、圆角、字号),不含任何颜色。
  static ButtonStyle buttonShapeStyle() => ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktopShell ? 4 : 6))),
        minimumSize: WidgetStatePropertyAll(
            isDesktopShell ? const Size(64, 40) : const Size(64, 36)),
        padding: WidgetStatePropertyAll(isDesktopShell
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
        textStyle: WidgetStatePropertyAll(isDesktopShell
            ? AppText.sm
            : AppText.base.copyWith(fontWeight: FontWeight.w500)),
        // 移动端保持默认 padded:36 的视觉高度外,可点区域仍撑到 48 不缩水。
        tapTargetSize: isDesktopShell ? MaterialTapTargetSize.shrinkWrap : null,
      );

  /// 大档:整页唯一主行动 / 通栏底栏(登录、poll 底栏、转发确认…)。
  /// 只放大形态不带颜色,FilledButton / FilledButton.tonal 都能叠;
  /// 需要同时改色时:FilledButton.styleFrom(backgroundColor: …).merge(largeButtonStyle())。
  static ButtonStyle largeButtonStyle() => ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
            isDesktopShell ? const Size(80, 48) : const Size(64, 44)),
        padding: WidgetStatePropertyAll(isDesktopShell
            ? const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
        textStyle: WidgetStatePropertyAll(isDesktopShell
            ? AppText.base
            : AppText.lg.copyWith(fontWeight: FontWeight.w500)),
      );

  /// 文字动作:前景色走组件默认值(colorScheme.primary,即品牌蓝),
  /// 这里只收桌面字号与点击区。
  static ButtonStyle textButtonStyle() => ButtonStyle(
        textStyle:
            isDesktopShell ? const WidgetStatePropertyAll(AppText.sm) : null,
        tapTargetSize: isDesktopShell ? MaterialTapTargetSize.shrinkWrap : null,
      );

  /// 对话框「取消」位的压灰文字动作,弱于右侧的确认位。
  static ButtonStyle mutedTextButtonStyle(AppColors colors) =>
      TextButton.styleFrom(foregroundColor: colors.textSecondary);

  /// 开关(Switch)的主题:收紧点击区域,选中品牌蓝。
  static SwitchThemeData switchTheme(AppColors colors, Brightness brightness) {
    return SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colors.onAccent;
        }
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colors.accent;
        }
        return null;
      }),
    );
  }

  /// 圆形勾选框(微信风格):选中品牌蓝,禁用置灰。
  /// 选人、多选消息等场景全端统一观感;挂在全局 ThemeData 与 PcTheme 上。
  ///
  /// 描边/禁用灰是勾选框自己的中性灰,不复用文字令牌 —— 文字灰在暗色下
  /// (#636366)压不住 #2C2C2E 的面,描边会看不见。
  static CheckboxThemeData checkboxTheme(
      AppColors colors, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final borderGray =
        isDark ? const Color(0xFF5A5A5C) : const Color(0xFFC0C0C0);
    final disabledGray =
        isDark ? const Color(0xFF48484A) : const Color(0xFFC6C6C6);
    return CheckboxThemeData(
      shape: const CircleBorder(),
      side: BorderSide(color: borderGray, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return states.contains(WidgetState.disabled)
            ? disabledGray
            : colors.accent;
      }),
      checkColor: WidgetStatePropertyAll(colors.onAccent),
    );
  }

  /// 移动端状态栏 / 导航栏图标的明暗。桌面端不使用。
  /// 传入的是「界面」的明暗,图标要取反才看得见。
  static SystemUiOverlayStyle systemOverlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark ? AppColors.dark : AppColors.light;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: colors.cellTop,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );
  }
}
