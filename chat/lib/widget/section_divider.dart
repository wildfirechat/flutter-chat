import 'package:flutter/widgets.dart';

import 'package:chat/theme/app_colors.dart';
import 'package:chat/app_shell.dart';

/// 分组列表之间的段间分隔。
///
/// 移动端:18px 透明占位,露出底层的凹槽灰(微信移动端形态)。
/// 桌面端:整页共用一张白底,分组之间只留一条左右缩进的弱发丝线(微信 PC 形态)——
/// 桌面窗口里再压一条 18px 的灰带,会把本来就窄的右栏切得很碎。
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});

  /// 段间纵向间距。列表**尾部**的收尾留白请直接用它,不要用 [SectionDivider]:
  /// 桌面端那会在内容底部留下一条没有下文的悬空线。
  static const double gap = 18;

  @override
  Widget build(BuildContext context) {
    if (!AppShell.isDesktopStyle) {
      return const SizedBox(height: gap);
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 0.5,
      color: context.colors.hairlineSoft,
    );
  }
}
