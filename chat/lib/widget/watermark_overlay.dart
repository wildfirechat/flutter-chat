import 'dart:async';
import 'dart:math' show pi;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config.dart';

/// 全局安全水印。
///
/// 覆盖在应用内容之上，显示当前用户 ID + 动态时间，倾斜平铺。
/// 开关由 [Config.ENABLE_WATER_MARKER] 控制。
class WatermarkOverlay extends StatefulWidget {
  final String? userId;

  const WatermarkOverlay({super.key, this.userId});

  @override
  State<WatermarkOverlay> createState() => _WatermarkOverlayState();
}

class _WatermarkOverlayState extends State<WatermarkOverlay> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Config.ENABLE_WATER_MARKER) {
      return const SizedBox.shrink();
    }

    final text = '${widget.userId ?? ''}  ${DateFormat('MM-dd HH:mm').format(_now)}';
    final size = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06);

    return IgnorePointer(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: CustomPaint(
          painter: _WatermarkPainter(text: text, color: color),
          size: Size(size.width, size.height),
        ),
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  final String text;
  final Color color;

  _WatermarkPainter({required this.text, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      fontSize: 14,
      color: color,
      fontWeight: FontWeight.w500,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    const gapX = 120.0;
    const gapY = 80.0;
    const rotation = -15 * pi / 180;

    canvas.save();
    // 扩大绘制区域，保证旋转后边缘也被覆盖
    canvas.translate(-size.width * 0.25, -size.height * 0.25);
    final width = size.width * 1.5;
    final height = size.height * 1.5;

    for (double y = 0; y < height; y += gapY) {
      for (double x = 0; x < width; x += gapX) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rotation);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter oldDelegate) {
    return oldDelegate.text != text || oldDelegate.color != color;
  }
}
