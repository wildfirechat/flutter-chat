import 'package:flutter/material.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

/// 图标在上、文字在下的动作项(发消息 / 音频通话 / 视频通话)。
/// PC 用户卡片与用户资料页共用。宽度包住文字即可,不平分整行;
/// 多个并排时外面套 Wrap,译文过长时换行而非溢出。
class PcIconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// 资料页里图标与文字同为 accent(微信 PC 的形态);卡片里文字压到次级色。
  final Color? labelColor;
  final double iconSize;

  const PcIconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: hovered ? colors.hoverOverlay : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: colors.accent),
              const SizedBox(height: 5),
              Text(label, style: AppText.xs.copyWith(color: labelColor ?? colors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
