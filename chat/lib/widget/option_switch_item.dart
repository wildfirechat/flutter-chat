import 'package:flutter/material.dart';
import 'package:chat/theme/app_colors.dart';
import '../utils/layout_scale.dart';
import 'package:chat/theme/app_typography.dart';

class OptionSwitchItem extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showBottomDivider;

  const OptionSwitchItem(
    this.title,
    this.value,
    this.onChanged, {
    this.showBottomDivider = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final rowHeight = LayoutScale.watchScale(context, 36.0, cap: LayoutScale.rowCap);
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
              constraints: BoxConstraints(minHeight: rowHeight),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppText.lg,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.6,
                    child: Switch(
                      value: value,
                      onChanged: onChanged,
                    ),
                  )
                ],
              ),
            ),
            showBottomDivider
                ? Container(
                    margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
                    height: 0.5,
                    color: colors.hairline,
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
