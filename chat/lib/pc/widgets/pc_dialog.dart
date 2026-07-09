import 'package:flutter/material.dart';

import 'package:chat/pc/pc_theme.dart';
import 'package:chat/theme/app_colors.dart';

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
    barrierColor: context.colors.scrim,
    builder: (dialogContext) {
      // 弹窗挂在根导航器上,调用方 context 若在 PCHome 的 Theme 子树之外
      // (如 _PCHomeState 自身),showDialog 捕获不到桌面主题,这里统一补上。
      return Theme(
        data: PcTheme.themeData(dialogContext),
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          backgroundColor: dialogContext.colors.surface,
          elevation: 12,
          child: SizedBox(
            width: width,
            height: height,
            child: Builder(builder: builder),
          ),
        ),
      );
    },
  );
}
