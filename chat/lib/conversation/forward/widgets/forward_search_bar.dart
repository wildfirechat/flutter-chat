import 'package:flutter/material.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/l10n/app_localizations.dart';

/// 转发 / 建群选人共用的圆角搜索框。
///
/// [chips] 是内联在输入框左侧的已选头像(移动端用);桌面端把已选放在右栏,传空即可。
class ForwardSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final List<Widget> chips;

  /// 已选头像区的最大宽度,超出后横向滚动。
  final double? maxChipsWidth;

  const ForwardSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.chips = const [],
    this.maxChipsWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.colors.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: context.colors.inputBg,
          borderRadius: BorderRadius.circular(6),
        ),
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          children: [
            Icon(Icons.search, color: context.colors.iconSecondary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  if (chips.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxChipsWidth ?? double.infinity),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(mainAxisSize: MainAxisSize.min, children: chips),
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.search,
                        hintStyle: TextStyle(color: context.colors.textSecondary, fontSize: 14),
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
