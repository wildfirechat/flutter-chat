import 'package:flutter/material.dart';

/// 全端共享的品牌样式令牌(移动端 + 桌面端通用)。
/// 桌面端布局/配色的专属令牌在 pc/pc_theme.dart,跨端需要一致的样式收敛在这里。
class AppTheme {
  AppTheme._();

  /// 品牌蓝,PcTheme.accent 与此同源。
  static const Color accent = Color(0xFF1F64E4);

  /// 圆形勾选框(微信风格):选中品牌蓝,禁用置灰。
  /// 选人、多选消息等场景全端统一观感;挂在 main.dart 全局主题与 PcTheme 上。
  static final CheckboxThemeData checkboxTheme = CheckboxThemeData(
    shape: const CircleBorder(),
    side: const BorderSide(color: Color(0xFFC0C0C0), width: 1.5),
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (!states.contains(WidgetState.selected)) {
        return Colors.transparent;
      }
      return states.contains(WidgetState.disabled) ? const Color(0xFFC6C6C6) : accent;
    }),
    checkColor: const WidgetStatePropertyAll(Colors.white),
  );
}
