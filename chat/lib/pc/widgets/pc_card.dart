import 'package:flutter/material.dart';
import 'package:chat/theme/app_colors.dart';

/// 桌面端限宽正文里的分组卡片:圆角 + 弱边框的一张面。
///
/// 正文一旦限宽居中([PcPaneContent]),白底就不能再直接铺在白底上 —— 面板底是
/// chatBgDesktop,卡片是 surface,这道边界替代了原先整页白底时靠 SectionDivider
/// 交代的分组关系。卡片内部行与行之间不画线,靠行高留白分隔。
class PcCard extends StatelessWidget {
  final List<Widget> children;

  const PcCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.hairline, width: 0.5),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}
