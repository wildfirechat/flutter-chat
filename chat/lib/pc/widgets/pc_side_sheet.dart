import 'package:flutter/material.dart';

/// 右栏内的右侧抽屉(参照微信 PC 的会话详情面板):
/// 从右缘滑入固定宽度面板,浅色遮罩点击/Esc 关闭。
/// 必须用右栏嵌套 Navigator 的 context 调用,遮罩只覆盖右栏区域。
Future<T?> showPcSideSheet<T>({
  required BuildContext context,
  double width = 340,
  required WidgetBuilder builder,
}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: true,
      // 不做遮罩(微信形态):面板靠投影区分层次,点击面板外仍可关闭
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: width,
          child: Material(
            elevation: 16,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            child: Builder(builder: builder),
          ),
        ),
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}
