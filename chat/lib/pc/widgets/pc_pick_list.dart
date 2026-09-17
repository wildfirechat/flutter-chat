import 'package:flutter/material.dart';

import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/layout_scale.dart';

// 桌面端选人弹窗的列表零件:搜索框、分段标题、勾选行。
// 联系人列表与组织架构浏览器共用,保证两种来源的行长得一样。

class PcPickSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const PcPickSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: context.colors.inputBg,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Icon(Icons.search, size: 16, color: context.colors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                style: AppText.sm.copyWith(color: context.colors.textPrimary),
                cursorColor: context.colors.accent,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: hint,
                  hintStyle:
                      AppText.sm.copyWith(color: context.colors.textTertiary),
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PcPickSectionHeader extends StatelessWidget {
  final String text;

  const PcPickSectionHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: LayoutScale.watchScale(context, 24.0, cap: LayoutScale.textCap),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        text,
        style: AppText.xs.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}

/// 勾选行:勾选框 + 头像 + 名称(可选副标题)。
class PcCheckableRow extends StatelessWidget {
  final bool checkable;
  final bool checked;
  final ValueChanged<bool> onToggle;
  final Widget avatar;
  final String title;
  final String? subtitle;

  const PcCheckableRow({
    super.key,
    required this.checkable,
    required this.checked,
    required this.onToggle,
    required this.avatar,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: checkable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      builder: (context, hovered) => GestureDetector(
        onTap: checkable ? () => onToggle(!checked) : null,
        child: Container(
          height:
              LayoutScale.watchScale(context, 48.0, cap: LayoutScale.rowCap),
          color: checkable && hovered
              ? context.colors.hoverOverlay
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: checkable ? (value) => onToggle(value!) : null,
              ),
              const SizedBox(width: 10),
              avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Opacity(
                  opacity: checkable ? 1.0 : 0.5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.sm
                            .copyWith(color: context.colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          style: AppText.xs
                              .copyWith(color: context.colors.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
