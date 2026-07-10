import 'package:flutter/material.dart';
import 'package:chat/theme/app_colors.dart';
import '../utils/layout_scale.dart';

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
        hoverColor: colors.hoverOverlay,
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
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  desc != null && desc!.isNotEmpty
                      ? Container(
                          constraints: const BoxConstraints(maxWidth: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            desc!,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(color: colors.textSecondary, fontSize: 14),
                          ),
                        )
                      : Container(),
                  rightImage != null || rightIcon != null
                      ? Container(
                          height: iconSize,
                          width: iconSize,
                          margin: const EdgeInsets.fromLTRB(12, 0, 0, 0),
                          child: rightImage ?? Icon(rightIcon, size: iconSize),
                        )
                      : const SizedBox.shrink(),
                  showRightArrow
                      ? Icon(Icons.chevron_right, size: LayoutScale.watchScale(context, 24.0), color: colors.textTertiary)
                      : Container(),
                ],
              ),
            ),
            showBottomDivider
                ? Container(
                    margin: EdgeInsets.fromLTRB(
                      (leftImage != null || leftIcon != null)
                          ? (15.0 + iconSize + 12.0)
                          : 15.0,
                      0.0,
                      12.0,
                      0.0,
                    ),
                    height: 0.5,
                    color: colors.hairline,
                  )
                : Container(),
          ],
        ),
      ),
    );
  }
}
