import 'package:flutter/material.dart';

import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

/// 表单卡片:白/深面 + 圆角,行与行之间自动补一条发丝线。
///
/// 线由卡片统一画,放进来的 [OptionItem]/[OptionSwitchItem] 请传
/// `showBottomDivider: false` —— 两边都画就会出现双线。
///
/// 与设置页的分组列表([SectionDivider] 分段、行间不画线)不是一回事:
/// 那里靠段间凹槽分组,这里是一张有边界的表单卡,行间线用来交代字段边界。
class FormCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const FormCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider());
      }
      rows.add(children[i]);
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: padding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }
}

/// 卡片上方的小标题(如「投票选项」)。
class FormSectionLabel extends StatelessWidget {
  final String text;

  const FormSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: AppText.xs.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}

/// 表单卡片里的无边框输入行。
class FormTextRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;

  const FormTextRow({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = style ?? AppText.lg;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: base.copyWith(color: colors.textPrimary),
      cursorColor: colors.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: base.copyWith(color: colors.textTertiary),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onChanged: onChanged,
    );
  }
}

/// 单选选择器:一列选项,当前项打勾。取消(点遮罩/返回)返回 null。
///
/// 取代 `RadioListTile` + 手写 AlertDialog:两端观感一致,且不必在调用点
/// 自己维护 groupValue。
Future<T?> showFormOptionPicker<T>({
  required BuildContext context,
  required String title,
  required T current,
  required List<({T value, String label})> options,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return SimpleDialog(
        title: Text(title, style: AppText.lg.copyWith(color: colors.textPrimary)),
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        children: [
          for (final option in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, option.value),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      style: AppText.base.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  if (option.value == current) Icon(Icons.check, size: 18, color: colors.accent),
                ],
              ),
            ),
        ],
      );
    },
  );
}
