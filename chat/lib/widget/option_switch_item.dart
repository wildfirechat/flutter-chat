import 'package:flutter/material.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/theme/app_colors.dart';
import '../utils/layout_scale.dart';
import 'package:chat/theme/app_typography.dart';
import 'app_switch.dart';

class OptionSwitchItem extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showBottomDivider;

  /// 开关左侧的说明文字(如免打扰时段),右对齐、次要色,同 [OptionItem] 的 desc。
  final String? desc;

  const OptionSwitchItem(
    this.title,
    this.value,
    this.onChanged, {
    this.showBottomDivider = true,
    this.desc,
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
                  AppSwitch(
                    value: value,
                    onChanged: onChanged,
                  )
                ],
              ),
            ),
            // 桌面端行间不画线,与 OptionItem 保持一致(同一组里混着有线/无线会很花)。
            if (showBottomDivider && !isDesktopShell)
              const Divider(indent: 12, endIndent: 12),
          ],
        ),
      ),
    );
  }
}
