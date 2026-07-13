import 'package:flutter/material.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/theme/app_colors.dart';
import '../utils/layout_scale.dart';
import 'package:chat/theme/app_typography.dart';

/// 分组列表里的一行(标题 + 可选左图标/右值/右箭头)。
///
/// 桌面端刻意做减法(微信 PC 形态):行间不画分隔线(分组之间由 [SectionDivider] 的
/// 弱线交代),右箭头换成更细的一档,且不做 hover 反白 —— 可点性由鼠标指针交代。
class OptionItem extends StatelessWidget {
  final String title;
  final String? desc;
  final bool showRightArrow;
  final bool showBottomDivider;
  final Image? rightImage;
  final Widget? leftImage;
  final IconData? rightIcon;
  final IconData? leftIcon;
  final GestureTapCallback? onTap;

  const OptionItem(this.title,
      {super.key, this.desc = '', this.showRightArrow = true, this.showBottomDivider = true, this.onTap, this.leftImage, this.rightImage, this.leftIcon, this.rightIcon});

  @override
  Widget build(BuildContext context) {
    final rowHeight = LayoutScale.watchScale(context, 36.0, cap: LayoutScale.rowCap);
    final iconSize = LayoutScale.watchScale(context, 20.0, cap: LayoutScale.iconCap);
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: isDesktopShell ? Colors.transparent : colors.hoverOverlay,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
              constraints: BoxConstraints(minHeight: rowHeight),
              child: Row(
                children: [
                  leftImage != null || leftIcon != null
                      ? Container(
                          height: iconSize,
                          width: iconSize,
                          margin: const EdgeInsets.fromLTRB(0, 0, 12, 0),
                          child: leftImage ?? Icon(leftIcon, size: iconSize),
                        )
                      : const SizedBox.shrink(),
                  Text(
                    title,
                    maxLines: 1,
                    style: AppText.lg,
                  ),
                  const SizedBox(width: 8),
                  if (desc != null && desc!.isNotEmpty)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          desc!,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: AppText.base.copyWith(color: colors.textSecondary),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  rightImage != null || rightIcon != null
                      ? Container(
                          height: iconSize,
                          width: iconSize,
                          margin: const EdgeInsets.fromLTRB(12, 0, 0, 0),
                          child: rightImage ?? Icon(rightIcon, size: iconSize),
                        )
                      : const SizedBox.shrink(),
                  if (showRightArrow)
                    isDesktopShell
                        // 桌面端用更细的一档箭头(Material 的 chevron_right 在 PC 上过粗),
                        // 右边距补回 8:细箭头本身没有 chevron_right 那圈内白边。
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.arrow_forward_ios_rounded,
                                size: LayoutScale.watchScale(context, 13.0), color: colors.textTertiary),
                          )
                        : Icon(Icons.chevron_right,
                            size: LayoutScale.watchScale(context, 24.0), color: colors.textTertiary),
                ],
              ),
            ),
            // 桌面端行间不画线:分组内靠留白,分组之间由 SectionDivider 的弱线交代。
            if (showBottomDivider && !isDesktopShell)
              Divider(
                indent: (leftImage != null || leftIcon != null)
                    ? (15.0 + iconSize + 12.0)
                    : 15.0,
                endIndent: 12.0,
              ),
          ],
        ),
      ),
    );
  }
}
