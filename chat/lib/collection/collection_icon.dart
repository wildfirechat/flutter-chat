import 'package:flutter/material.dart';

import 'package:chat/theme/app_colors.dart';

/// 群接龙图标
///
/// 与 Android 端 ic_collection.xml 对应的 Flutter 实现
/// 使用 CustomPainter 绘制相同的图标样式
class CollectionIcon extends StatelessWidget {
  final double size;

  /// 不传则跟随主题的次级图标色 —— 写死深灰在暗色下会糊在深色底上。
  final Color? color;

  const CollectionIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter:
          _CollectionIconPainter(color: color ?? context.colors.iconSecondary),
    );
  }
}

class _CollectionIconPainter extends CustomPainter {
  final Color color;

  _CollectionIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;

    // 第一条线 (最上面，较短)
    // M17,9H7V7h10V9z -> Android pathData
    // 在 24x24 的 viewport 中，对应 Flutter 坐标
    final line1Rect = Rect.fromLTWH(
      width * 7 / 24, // x = 7
      height * 7 / 24, // y = 7
      width * 10 / 24, // width = 10
      height * 2 / 24, // height = 2
    );
    canvas.drawRect(line1Rect, paint);

    // 第二条线 (中间)
    // M17,13H7v-2h10V13z
    final line2Rect = Rect.fromLTWH(
      width * 7 / 24, // x = 7
      height * 11 / 24, // y = 11 (13-2)
      width * 10 / 24, // width = 10
      height * 2 / 24, // height = 2
    );
    canvas.drawRect(line2Rect, paint);

    // 第三条线 (最下面，最短)
    // M12,17H7v-2h5V17z
    final line3Rect = Rect.fromLTWH(
      width * 7 / 24, // x = 7
      height * 15 / 24, // y = 15 (17-2)
      width * 5 / 24, // width = 5 (12-7)
      height * 2 / 24, // height = 2
    );
    canvas.drawRect(line3Rect, paint);
  }

  @override
  bool shouldRepaint(covariant _CollectionIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
