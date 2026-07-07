import 'package:flutter/material.dart';

/// 桌面端通用紧凑型弹窗包装器
/// 自动限制最大宽度、圆角、背景色，保证与桌面端设计视觉深度一致。
Future<T?> showPcDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = 400,
  double? height,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.white,
        elevation: 12,
        child: SizedBox(
          width: width,
          height: height,
          child: builder(dialogContext),
        ),
      );
    },
  );
}
