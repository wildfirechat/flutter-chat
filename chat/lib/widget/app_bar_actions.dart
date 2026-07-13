import 'package:flutter/material.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

/// 移动端 AppBar 右上角文本动作按钮的统一规范组件。
///
/// 具备标准的字号（AppText.lg/16px）、字重（FontWeight.w600）、交互反馈色、
/// 禁用状态置灰逻辑、加载中（loading）转圈形态，以及统一样式的右侧边缘留白。
class AppBarTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? textColor;

  const AppBarTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeColor = textColor ?? colors.accent;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: activeColor,
          disabledForegroundColor: colors.textTertiary,
          textStyle: AppText.lg.copyWith(
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(60, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    onPressed == null ? colors.textTertiary : activeColor,
                  ),
                ),
              )
            : Text(label),
      ),
    );
  }
}
