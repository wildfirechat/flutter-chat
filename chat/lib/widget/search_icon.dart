import 'package:flutter/material.dart';

import 'package:chat/theme/app_colors.dart';

/// 放大镜图标
///
/// 与 Android 端 mipmap/ic_search.png 对应的 Flutter 实现。
///
/// Material 自带的 [Icons.search_rounded] 在 24 视口下镜片外径只有 13、尾巴却拖出
/// 4.5，和右边 [Icons.add_circle_outline_rounded]（圆环外径 20）并排时一眼看去一大
/// 一小。Android 端两个图标的圆分别是 16.3dp 和 20dp，所以这里按它的比例重画：
/// 镜片外径 16.5、尾巴只探出 1.5，整体墨迹 18，描边粗细与加号圆环同为 2。
class SearchIcon extends StatelessWidget {
  /// 不传则跟随 [IconTheme]（IconButton 会把 iconSize 塞进去），与 [Icon] 的行为一致。
  final double? size;

  /// 不传则跟随 [IconTheme] 的颜色，再退回主题主图标色。
  final Color? color;

  const SearchIcon({
    super.key,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    return CustomPaint(
      size: Size.square(size ?? iconTheme.size ?? 24),
      painter: _SearchIconPainter(
        color: color ?? iconTheme.color ?? context.colors.iconPrimary,
      ),
    );
  }
}

class _SearchIconPainter extends CustomPainter {
  final Color color;

  _SearchIconPainter({required this.color});

  /// 以下坐标都在 24x24 视口下，墨迹范围 3~21，和 Android 端 18dp 的图一一对应。
  /// 描边粗细取 2，与 [Icons.add_circle_outline_rounded] 的圆环等粗，两者并排不会一粗一细。
  static const double _strokeWidth = 2;

  /// 镜片圆心；描边中线半径 7.25，加上半个描边后外径 16.5，左上墨迹正好落在 3。
  static const double _center = 11.25;
  static const double _radius = 7.25;

  /// 手柄端点。圆头笔帽再向外探 1（半个描边），墨迹正好收在 21。
  static const double _handleEnd = 20;

  /// 手柄起点埋在圆环描边里（中线的 45° 点），所以看不出接缝。
  static const double _handleStart = _center + _radius * 0.7071067811865476;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth * unit
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
      Offset(_center * unit, _center * unit),
      _radius * unit,
      paint,
    );
    canvas.drawLine(
      Offset(_handleStart * unit, _handleStart * unit),
      Offset(_handleEnd * unit, _handleEnd * unit),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SearchIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
