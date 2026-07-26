import 'dart:async';
import 'dart:math' show pi;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import 'package:chat/theme/app_typography.dart';

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
    // 每秒检查一次,但只在分钟变化时才触发刷新,兼顾精度与重绘频率
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      if (now.minute != _now.minute ||
          now.hour != _now.hour ||
          now.day != _now.day) {
        setState(() {
          _now = now;
        });
      }
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

    // 主窗口经构造函数传入 userId;子窗口(独立 MaterialApp)未传时
    // 回退到 Imclient.currentUserId(子窗口 init 时已设置,见
    // SubWindowAppBase._init),均未设置则只显示时间。
    final effectiveUserId = widget.userId ?? Imclient.currentUserId;
    final text = '$effectiveUserId  ${DateFormat('MM-dd HH:mm').format(_now)}';
    final size = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    // 深色背景下同等 alpha 的白字比浅色背景下的黑字更不明显，故给深色多一点
    final color = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

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
    final textStyle = AppText.sm.copyWith(color: color, fontWeight: FontWeight.w400);
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    // 步长必须大于文字自身宽度，否则相邻水印会互相重叠、显得很密
    final stepX = textPainter.width + 140;
    const stepY = 150.0;
    const rotation = -15 * pi / 180;

    canvas.save();
    // 扩大绘制区域，保证旋转后边缘也被覆盖
    canvas.translate(-size.width * 0.25, -size.height * 0.25);
    final width = size.width * 1.5;
    final height = size.height * 1.5;

    int row = 0;
    for (double y = 0; y < height; y += stepY) {
      // 奇数行错开半个步长，密度降低后仍能均匀覆盖
      final offsetX = (row.isOdd ? stepX / 2 : 0) - stepX;
      for (double x = offsetX; x < width; x += stepX) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rotation);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
      row++;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter oldDelegate) {
    return oldDelegate.text != text || oldDelegate.color != color;
  }
}
