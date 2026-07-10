import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chat/theme/app_colors.dart';

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
      dividerTheme: base.dividerTheme.copyWith(color: colors.hairlineSoft),
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
      dividerTheme: base.dividerTheme.copyWith(color: colors.hairlineSoft),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accent.withValues(alpha: 0.35),
        selectionHandleColor: colors.accent,
      ),
    );
  }

  static ThemeData _withColors(ThemeData base, AppColors colors) => base.copyWith(
        extensions: <ThemeExtension<dynamic>>[colors],
        checkboxTheme: checkboxTheme(colors, base.brightness),
      );

  /// 圆形勾选框(微信风格):选中品牌蓝,禁用置灰。
  /// 选人、多选消息等场景全端统一观感;挂在全局 ThemeData 与 PcTheme 上。
  ///
  /// 描边/禁用灰是勾选框自己的中性灰,不复用文字令牌 —— 文字灰在暗色下
  /// (#636366)压不住 #2C2C2E 的面,描边会看不见。
  static CheckboxThemeData checkboxTheme(AppColors colors, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final borderGray = isDark ? const Color(0xFF5A5A5C) : const Color(0xFFC0C0C0);
    final disabledGray = isDark ? const Color(0xFF48484A) : const Color(0xFFC6C6C6);
    return CheckboxThemeData(
      shape: const CircleBorder(),
      side: BorderSide(color: borderGray, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return states.contains(WidgetState.disabled) ? disabledGray : colors.accent;
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
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );
  }
}
