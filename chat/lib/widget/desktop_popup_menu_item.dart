import 'package:flutter/material.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/theme/app_typography.dart';

/// 桌面端定制上下文菜单项
/// 支持悬停状态(hover)样式定制,以及危险操作(如删除)的高亮警示样式
class DesktopPopupMenuItem<T> extends PopupMenuEntry<T> {
  const DesktopPopupMenuItem({
    super.key,
    required this.value,
    required this.child,
    this.height = 34,
    this.isDanger = false,
  });

  final T value;
  final Widget child;
  @override
  final double height;
  final bool isDanger;

  @override
  bool represents(T? value) => this.value == value;

  @override
  State<DesktopPopupMenuItem<T>> createState() =>
      _DesktopPopupMenuItemState<T>();
}

class _DesktopPopupMenuItemState<T> extends State<DesktopPopupMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopupMenuItem<T>(
      value: widget.value,
      height: widget.height,
      padding: EdgeInsets.zero,
      child: HoverBuilder(
        builder: (context, hovered) {
          final Color textColor = hovered
              ? Colors.white
              : (widget.isDanger ? colors.danger : colors.textPrimary);

          final Color iconColor = hovered
              ? Colors.white
              : (widget.isDanger ? colors.danger : colors.textPrimary);

          final Color bgColor = hovered
              ? (widget.isDanger ? colors.danger : colors.accent)
              : Colors.transparent;

          return Container(
            width: double.infinity,
            height: widget.height,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: DefaultTextStyle(
              style: AppText.sm.copyWith(
                  color: textColor,
                  fontFamily:
                      Theme.of(context).textTheme.bodyMedium?.fontFamily),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: iconColor,
                  size: 16,
                ),
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}
