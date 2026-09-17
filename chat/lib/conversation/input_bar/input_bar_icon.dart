import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:chat/theme/app_colors.dart';

/// 移动端输入栏的圆框线性图标。
enum InputBarGlyph { voice, keyboard, emoji, plugin, menu }

/// 矢量绘制的输入栏图标。
///
/// 原先用的是 48px 单倍图、按 32 逻辑像素显示，3x 屏上被放大一倍发虚；
/// 颜色又是写死的半透明灰，暗色模式下几乎看不见。改为按 24×24 网格矢量绘制，
/// 任意像素密度都清晰，颜色默认走 [AppColors.iconPrimary]。
class InputBarIcon extends StatelessWidget {
  const InputBarIcon(this.glyph, {super.key, this.size = 32, this.color});

  final InputBarGlyph glyph;
  final double size;

  /// 为空时取 [AppColors.iconPrimary]
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter:
          _InputBarGlyphPainter(glyph, color ?? context.colors.iconPrimary),
    );
  }
}

class _InputBarGlyphPainter extends CustomPainter {
  _InputBarGlyphPainter(this.glyph, this.color);

  final InputBarGlyph glyph;
  final Color color;

  /// 以下尺寸都是 24×24 网格单位。32 逻辑像素下 1 单位 ≈ 1.33pt。
  /// 颜色与 AppBar 返回箭头同值(textPrimary),但圆框图标墨量大、同色也显得更重,
  /// 所以线宽比返回箭头(约 2pt)收细一档
  static const double _stroke = 1.2;
  static const double _ringRadius = 10.1;
  static const Offset _center = Offset(12, 12);

  @override
  void paint(Canvas canvas, Size size) {
    // 父级给 tight 约束时 CustomPaint 的 size 会被忽略、画布可能不是正方形,
    // 按短边等比缩放并居中,避免圆框被拉成椭圆
    final double side = math.min(size.width, size.height);
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 24);
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    final Paint fill = Paint()..color = color;

    canvas.drawCircle(_center, _ringRadius, stroke);

    switch (glyph) {
      case InputBarGlyph.voice:
        _paintVoice(canvas, stroke, fill);
      case InputBarGlyph.keyboard:
        _paintKeyboard(canvas, stroke, fill);
      case InputBarGlyph.emoji:
        _paintEmoji(canvas, stroke, fill);
      case InputBarGlyph.plugin:
        _paintPlugin(canvas, stroke);
      case InputBarGlyph.menu:
        _paintMenu(canvas, stroke);
    }
  }

  /// 扇形 + 两道声波，朝右
  void _paintVoice(Canvas canvas, Paint stroke, Paint fill) {
    const Offset apex = Offset(7.2, 12);
    const double start = -math.pi / 4;
    const double sweep = math.pi / 2;
    canvas.drawArc(
        Rect.fromCircle(center: apex, radius: 3), start, sweep, true, fill);
    for (final double radius in const [5.4, 8.6]) {
      canvas.drawArc(Rect.fromCircle(center: apex, radius: radius), start,
          sweep, false, stroke);
    }
  }

  /// 两排按键 + 空格键，不画键盘外框（圆框里再套矩形太繁）
  void _paintKeyboard(Canvas canvas, Paint stroke, Paint fill) {
    for (final double y in const [9.0, 12.0]) {
      for (final double x in const [7.8, 10.6, 13.4, 16.2]) {
        canvas.drawCircle(Offset(x, y), 0.75, fill);
      }
    }
    canvas.drawLine(const Offset(9, 15.2), const Offset(15, 15.2), stroke);
  }

  /// 两点眼睛 + 弧形嘴
  void _paintEmoji(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawCircle(const Offset(8.8, 9.3), 1.1, fill);
    canvas.drawCircle(const Offset(15.2, 9.3), 1.1, fill);
    const double smileStart = 25 * math.pi / 180;
    canvas.drawArc(Rect.fromCircle(center: const Offset(12, 11), radius: 4.4),
        smileStart, math.pi - 2 * smileStart, false, stroke);
  }

  void _paintPlugin(Canvas canvas, Paint stroke) {
    const double half = 4.4;
    canvas.drawLine(
        const Offset(12, 12 - half), const Offset(12, 12 + half), stroke);
    canvas.drawLine(
        const Offset(12 - half, 12), const Offset(12 + half, 12), stroke);
  }

  void _paintMenu(Canvas canvas, Paint stroke) {
    for (final double y in const [8.5, 12.0, 15.5]) {
      canvas.drawLine(Offset(7.8, y), Offset(16.2, y), stroke);
    }
  }

  @override
  bool shouldRepaint(_InputBarGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
