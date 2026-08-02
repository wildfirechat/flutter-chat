import 'package:flutter/material.dart';

import 'package:chat/theme/app_colors.dart';

/// 群投票图标
///
/// 与鸿蒙端 ic_ext_poll.svg 对应的 Flutter 实现，
/// 笔画粗细与 [CollectionIcon] 一致（24 视口下 2 个单位），两者并排才不会一粗一细。
class PollIcon extends StatelessWidget {
  final double size;

  /// 不传则跟随主题的次级图标色 —— 写死深灰在暗色下会糊在深色底上。
  final Color? color;

  const PollIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PollIconPainter(color: color ?? context.colors.iconSecondary),
    );
  }
}

class _PollIconPainter extends CustomPainter {
  final Color color;

  _PollIconPainter({required this.color});

  /// 三根柱子在 24x24 视口中的 (left, top)，宽 2、下沿统一到 y=17。
  /// 对应 svg path：M9 17H7V10H9V17ZM13 17H11V7H13V17ZM17 17H15V13H17V17Z
  static const List<List<double>> _bars = [
    [7, 10],
    [11, 7],
    [15, 13],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final unitX = size.width / 24;
    final unitY = size.height / 24;

    for (final bar in _bars) {
      canvas.drawRect(
        Rect.fromLTRB(
          bar[0] * unitX,
          bar[1] * unitY,
          (bar[0] + 2) * unitX,
          17 * unitY,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PollIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
