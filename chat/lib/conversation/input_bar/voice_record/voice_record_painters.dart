import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'voice_record_geometry.dart';
import 'voice_record_style.dart';

/// 浮层背景：整屏半透明的深色遮罩，操作区底部再叠一块深灰色背景，上边缘从透明线性渐变到不透明。
/// 录音时深灰背景从弧形按钮处开始，编辑文字时升到气泡下方
class VoiceInputBackgroundPainter extends CustomPainter {
  const VoiceInputBackgroundPainter({
    required this.progress,
    required this.stageLeft,
    required this.stageRight,
    required this.panelTop,
  });

  /// 深灰背景上边缘渐变区域的高度
  static const double fadeHeight = 130;

  /// 显示程度，0 完全透明，1 完全显示
  final double progress;

  /// 深灰背景的左右边界，双栏时只覆盖会话界面
  final double stageLeft;
  final double stageRight;

  /// 深灰背景完全不透明处的 y 坐标
  final double panelTop;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }
    canvas.drawRect(Offset.zero & size,
        Paint()..color = _scaleAlpha(VoiceRecordPalette.dim, progress));
    if (stageRight <= stageLeft) {
      return;
    }
    final double fadeTop = panelTop - fadeHeight;
    final Color panel = _scaleAlpha(VoiceRecordPalette.panel, progress);
    final Paint paint = Paint()
      ..shader = ui.Gradient.linear(Offset(0, fadeTop), Offset(0, panelTop),
          [panel.withValues(alpha: 0), panel]);
    canvas.drawRect(
        Rect.fromLTRB(
            stageLeft, math.max(0.0, fadeTop), stageRight, size.height),
        paint);
  }

  @override
  bool shouldRepaint(VoiceInputBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.stageLeft != stageLeft ||
      oldDelegate.stageRight != stageRight ||
      oldDelegate.panelTop != panelTop;
}

/// 底部操作区上的文字
@immutable
class VoiceRecordBottomLabels {
  const VoiceRecordBottomLabels({
    required this.voice,
    required this.releaseToSend,
    required this.cancel,
    required this.releaseToCancel,
    required this.slideToText,
    required this.releaseToEdit,
  });

  final String voice;
  final String releaseToSend;
  final String cancel;
  final String releaseToCancel;
  final String slideToText;
  final String releaseToEdit;

  @override
  bool operator ==(Object other) =>
      other is VoiceRecordBottomLabels &&
      other.voice == voice &&
      other.releaseToSend == releaseToSend &&
      other.cancel == cancel &&
      other.releaseToCancel == releaseToCancel &&
      other.slideToText == slideToText &&
      other.releaseToEdit == releaseToEdit;

  @override
  int get hashCode => Object.hash(voice, releaseToSend, cancel,
      releaseToCancel, slideToText, releaseToEdit);
}

/// 按住说话时的底部操作区：最下方弧形的“松开 发送”区域，上方左右两条弧形的“取消”和“转文字”按钮
class VoiceRecordBottomPainter extends CustomPainter {
  const VoiceRecordBottomPainter({
    required this.layout,
    required this.labels,
    required this.textStyle,
    required this.textScaler,
    required this.speechToTextEnabled,
    required this.appear,
    required this.selection,
  });

  final VoiceRecordLayout layout;
  final VoiceRecordBottomLabels labels;
  final TextStyle textStyle;
  final TextScaler textScaler;

  /// 是否显示“转文字”按钮
  final bool speechToTextEnabled;

  /// 入场进度，0 完全隐藏，1 完全显示
  final double appear;

  /// 各个目标的高亮程度，0~1，按 [VoiceRecordZone.index] 索引
  final List<double> selection;

  @override
  void paint(Canvas canvas, Size size) {
    if (appear <= 0) {
      return;
    }
    canvas.save();
    canvas.clipRect(
        Rect.fromLTRB(layout.stageLeft, 0, layout.stageRight, size.height));
    _drawArcArea(canvas, size);
    // 按钮比弧形区域稍晚升起，更早落下
    final double pillAppear = ((appear - 0.15) / 0.85).clamp(0.0, 1.0);
    if (pillAppear > 0) {
      canvas.save();
      canvas.translate(0, (1 - pillAppear) * (size.height - layout.pillTop));
      _drawPill(canvas,
          left: true,
          selected: selection[VoiceRecordZone.cancel.index],
          label: labels.cancel,
          hint: labels.releaseToCancel,
          alpha: pillAppear);
      if (speechToTextEnabled) {
        _drawPill(canvas,
            left: false,
            selected: selection[VoiceRecordZone.text.index],
            label: labels.slideToText,
            hint: labels.releaseToEdit,
            alpha: pillAppear);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  void _drawArcArea(Canvas canvas, Size size) {
    final double selected = selection[VoiceRecordZone.send.index];
    final Offset center = Offset(layout.centerX, layout.arcCenterY);
    final double radius = layout.arcRadius;
    canvas.save();
    canvas.translate(0, (1 - appear) * (size.height - layout.arcTop));
    canvas.drawCircle(center, radius, Paint()..color = VoiceRecordPalette.arc);
    if (selected > 0) {
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = ui.Gradient.linear(
                Offset(0, layout.arcTop),
                Offset(0, math.max(layout.arcTop + 1, size.height)),
                [
                  _scaleAlpha(VoiceRecordPalette.arcSelectedTop, selected),
                  _scaleAlpha(VoiceRecordPalette.arcSelectedBottom, selected),
                ]));
      canvas.drawCircle(
          center,
          radius - 1,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _scaleAlpha(VoiceRecordPalette.arcRim, selected));
    }
    // “语音”和“松开 发送”交叉淡入淡出，文字同时轻微上移
    final double labelCenterY = layout.arcTop + 44 - 8 * selected;
    _drawCenteredText(canvas, labels.voice, labelCenterY,
        _scaleAlpha(VoiceRecordPalette.arcLabel, 1 - selected));
    _drawCenteredText(canvas, labels.releaseToSend, labelCenterY,
        _scaleAlpha(VoiceRecordPalette.selectedLabel, selected));
    canvas.restore();
  }

  void _drawCenteredText(
      Canvas canvas, String text, double centerY, Color color) {
    if (color.a <= 0) {
      return;
    }
    final TextPainter painter =
        _layoutText(text, VoiceRecordTextSize.arcLabel, color);
    painter.paint(canvas,
        Offset(layout.centerX - painter.width / 2, centerY - painter.height / 2));
    painter.dispose();
  }

  void _drawPill(
    Canvas canvas, {
    required bool left,
    required double selected,
    required String label,
    required String hint,
    required double alpha,
  }) {
    final double radius = layout.pillRadius;
    // 选中时稍微变粗
    final double thickness = layout.pillThickness * (1 + 0.06 * selected);
    final double innerAngle = math.asin(
        (VoiceRecordLayout.pillGap / 2 + layout.pillThickness / 2) / radius);
    final double outerAngle = math.asin(
        math.min(1.0, (layout.stageWidth / 2 + thickness) / radius));
    // 圆的最高点是 -π/2，角度顺时针增加，弧线从左往右画
    final double startAngle =
        left ? -math.pi / 2 - outerAngle : -math.pi / 2 + innerAngle;
    canvas.drawArc(
        Rect.fromCircle(
            center: Offset(layout.centerX, layout.pillCenterY), radius: radius),
        startAngle,
        outerAngle - innerAngle,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round
          ..color = _scaleAlpha(
              Color.lerp(VoiceRecordPalette.pill,
                  VoiceRecordPalette.pillSelected, selected)!,
              alpha));

    final double offsetX = left ? -layout.labelOffsetX : layout.labelOffsetX;
    _drawTextOnArc(
        canvas,
        label,
        VoiceRecordTextSize.pillLabel,
        _scaleAlpha(
            Color.lerp(VoiceRecordPalette.pillLabel,
                VoiceRecordPalette.selectedLabel, selected)!,
            alpha),
        radius,
        offsetX,
        layout.maxLabelWidth);
    if (selected > 0) {
      // 按钮上方的提示随高亮淡入，并向上浮起
      final double hintRadius =
          radius + thickness / 2 + 24 - 8 * (1 - selected);
      _drawTextOnArc(
          canvas,
          hint,
          VoiceRecordTextSize.pillHint,
          _scaleAlpha(VoiceRecordPalette.pillHint, alpha * selected),
          hintRadius,
          offsetX,
          layout.maxLabelWidth + 40);
    }
  }

  /// 沿以 (centerX, pillCenterY) 为圆心、[radius] 为半径的圆弧逐字绘制文字，
  /// 文字中心在 centerX + [offsetX] 附近，太长时缩小字号
  void _drawTextOnArc(Canvas canvas, String text, double fontSize,
      Color color, double radius, double offsetX, double maxWidth) {
    if (color.a <= 0 || text.isEmpty) {
      return;
    }
    List<TextPainter> glyphs = _layoutGlyphs(text, fontSize, color);
    double width = _totalWidth(glyphs);
    if (width > maxWidth) {
      _disposeAll(glyphs);
      glyphs = _layoutGlyphs(text, fontSize * maxWidth / width, color);
      width = _totalWidth(glyphs);
    }
    final double centerAngle =
        math.asin((offsetX / radius).clamp(-1.0, 1.0));
    canvas.save();
    canvas.translate(layout.centerX, layout.pillCenterY);
    // 每个字的中心按弧长排在圆上，字随所在位置的切线旋转
    double arcOffset = -width / 2;
    for (final TextPainter glyph in glyphs) {
      canvas.save();
      canvas.rotate(centerAngle + (arcOffset + glyph.width / 2) / radius);
      glyph.paint(
          canvas, Offset(-glyph.width / 2, -radius - glyph.height / 2));
      canvas.restore();
      arcOffset += glyph.width;
    }
    canvas.restore();
    _disposeAll(glyphs);
  }

  List<TextPainter> _layoutGlyphs(String text, double fontSize, Color color) =>
      [
        for (final int rune in text.runes)
          _layoutText(String.fromCharCode(rune), fontSize, color),
      ];

  static double _totalWidth(List<TextPainter> glyphs) =>
      glyphs.fold(0, (sum, glyph) => sum + glyph.width);

  static void _disposeAll(List<TextPainter> painters) {
    for (final TextPainter painter in painters) {
      painter.dispose();
    }
  }

  TextPainter _layoutText(String text, double fontSize, Color color) =>
      TextPainter(
        text: TextSpan(
            text: text,
            style: textStyle.copyWith(fontSize: fontSize, color: color)),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();

  @override
  bool shouldRepaint(VoiceRecordBottomPainter oldDelegate) =>
      oldDelegate.appear != appear ||
      !listEquals(oldDelegate.selection, selection) ||
      oldDelegate.speechToTextEnabled != speechToTextEnabled ||
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.labels != labels ||
      oldDelegate.textStyle != textStyle ||
      oldDelegate.textScaler != textScaler;
}

/// 语音输入气泡：圆角矩形，底部有一个指向手势目标的小尖角，尖角画在底部 [VoiceRecordLayout.tailHeight] 的范围内
class VoiceBubblePainter extends CustomPainter {
  const VoiceBubblePainter({required this.color, required this.tailX});

  static const double _radius = 18;
  static const double _tailWidth = 18;

  final Color color;

  /// 尖角中心相对于气泡左边的位置
  final double tailX;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double bodyBottom = height - VoiceRecordLayout.tailHeight;
    if (width <= 0 || bodyBottom <= 0) {
      return;
    }
    final Paint paint = Paint()..color = color;
    final double radius =
        math.min(_radius, math.min(width, bodyBottom) / 2);
    canvas.drawRRect(
        RRect.fromLTRBR(0, 0, width, bodyBottom, Radius.circular(radius)),
        paint);

    const double half = _tailWidth / 2;
    final double x = math.max(math.min(radius + half, width / 2),
        math.min(math.max(width - radius - half, width / 2), tailX));
    // 尖角向上多画一点与气泡主体重叠，避免抗锯齿留下接缝；尖端画成小圆角
    const double tip = 1.5;
    final Path tail = Path()
      ..moveTo(x - half, bodyBottom - 1)
      ..lineTo(x - tip, height - 1)
      ..quadraticBezierTo(x, height, x + tip, height - 1)
      ..lineTo(x + half, bodyBottom - 1)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(VoiceBubblePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.tailX != tailX;
}

/// 语音输入的声波：一排圆角竖条，中间高两边低，高度随音量平滑起落；
/// 录音结束、等待识别结果时换成三个依次跳动的圆点
class VoiceWaveView extends StatefulWidget {
  const VoiceWaveView({
    super.key,
    required this.level,
    required this.loading,
    required this.color,
  });

  /// 音量，0~1
  final ValueListenable<double> level;

  /// 是否显示等待识别结果的动画
  final bool loading;
  final Color color;

  @override
  State<VoiceWaveView> createState() => _VoiceWaveViewState();
}

class _VoiceWaveViewState extends State<VoiceWaveView>
    with SingleTickerProviderStateMixin {
  final _VoiceWaveModel _model = _VoiceWaveModel();
  late final Ticker _ticker = createTicker(_model.advance);

  @override
  void initState() {
    super.initState();
    _model.loading = widget.loading;
    widget.level.addListener(_onLevelChanged);
    _ticker.start();
  }

  @override
  void didUpdateWidget(covariant VoiceWaveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.level, widget.level)) {
      oldWidget.level.removeListener(_onLevelChanged);
      widget.level.addListener(_onLevelChanged);
    }
    _model.loading = widget.loading;
  }

  @override
  void dispose() {
    widget.level.removeListener(_onLevelChanged);
    _ticker.dispose();
    _model.dispose();
    super.dispose();
  }

  void _onLevelChanged() => _model.setLevel(widget.level.value);

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(painter: _VoiceWavePainter(_model, widget.color)),
    );
  }
}

class _VoiceWaveModel extends ChangeNotifier {
  // 竖条升高、回落的时间常数，回落慢一些更自然
  static const double _riseTimeMs = 50;
  static const double _fallTimeMs = 140;

  // 声波和等待动画之间切换的时间常数
  static const double _loadingSwitchTimeMs = 100;

  static const double barWidth = 2;
  static const double barGap = 2.2;
  static const double minBarHeight = 3;
  static const double dotRadius = 2.6;
  static const double dotSpacing = 9;
  static const int dotCount = 3;

  final math.Random _random = math.Random();
  double _level = 0;
  bool loading = false;

  /// 等待动画的显示程度，0 显示声波，1 显示等待动画
  double loadingProgress = 0;

  /// 每个竖条当前的高度比例，0~1
  Float64List heights = Float64List(0);
  Float64List _targets = Float64List(0);

  /// 动画时间，等待动画的圆点按它跳动
  Duration time = Duration.zero;
  Duration? _lastFrameTime;

  void setLevel(double level) {
    _level = level.clamp(0.0, 1.0);
    _updateTargets();
  }

  /// 按宽度计算竖条数量。形态切换动画中宽度每帧都在变，所以在绘制时按实际宽度调用
  void resize(double width) {
    final int count =
        math.max(1, ((width + barGap) / (barWidth + barGap)).floor());
    if (count == heights.length) {
      return;
    }
    // 宽度变化时按比例重采样，形变过程中竖条高度不会突变
    final Float64List resized = Float64List(count);
    for (int i = 0; i < count; i++) {
      resized[i] = heights.isEmpty
          ? 0
          : heights[math.min(heights.length - 1, i * heights.length ~/ count)];
    }
    heights = resized;
    _targets = Float64List(count);
    _updateTargets();
  }

  void _updateTargets() {
    final int count = _targets.length;
    for (int i = 0; i < count; i++) {
      final double x = count == 1 ? 0 : i / (count - 1) * 2 - 1;
      final double envelope = 0.3 + 0.7 * math.exp(-x * x * 2.5);
      final double jitter = 0.5 + 0.5 * _random.nextDouble();
      // 不说话时也保留一点起伏
      final double idle = 0.06 + 0.1 * _random.nextDouble() * envelope;
      _targets[i] = math.min(1.0, idle + _level * envelope * jitter * 1.2);
    }
  }

  void advance(Duration elapsed) {
    final Duration? last = _lastFrameTime;
    final double dt = last == null
        ? 16
        : math.min(64.0, (elapsed - last).inMicroseconds / 1000);
    _lastFrameTime = elapsed;
    time = elapsed;
    loadingProgress += ((loading ? 1 : 0) - loadingProgress) *
        (1 - math.exp(-dt / _loadingSwitchTimeMs));
    for (int i = 0; i < heights.length; i++) {
      final double target = loading ? 0 : _targets[i];
      final double timeConstant =
          target > heights[i] ? _riseTimeMs : _fallTimeMs;
      heights[i] += (target - heights[i]) * (1 - math.exp(-dt / timeConstant));
    }
    notifyListeners();
  }
}

class _VoiceWavePainter extends CustomPainter {
  _VoiceWavePainter(this.model, this.color) : super(repaint: model);

  final _VoiceWaveModel model;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    model.resize(size.width);
    final Float64List heights = model.heights;
    final int count = heights.length;
    final double centerY = size.height / 2;
    // 等待识别结果时竖条落下并淡出
    final double barAlpha = 1 - model.loadingProgress;
    if (barAlpha > 0.01) {
      const double barWidth = _VoiceWaveModel.barWidth;
      final double totalWidth =
          count * barWidth + (count - 1) * _VoiceWaveModel.barGap;
      final double range =
          math.max(0.0, size.height - _VoiceWaveModel.minBarHeight);
      final Paint paint = Paint()..color = _scaleAlpha(color, barAlpha);
      double left = (size.width - totalWidth) / 2;
      for (int i = 0; i < count; i++) {
        final double height = _VoiceWaveModel.minBarHeight + range * heights[i];
        canvas.drawRRect(
            RRect.fromLTRBR(left, centerY - height / 2, left + barWidth,
                centerY + height / 2, const Radius.circular(barWidth / 2)),
            paint);
        left += barWidth + _VoiceWaveModel.barGap;
      }
    }
    final double loadingProgress = model.loadingProgress;
    if (loadingProgress > 0.01) {
      // 三个圆点从左到右依次变大变亮
      final double phase =
          model.time.inMicroseconds / 1e6 * math.pi * 2 * 1.2;
      final Paint paint = Paint();
      for (int i = 0; i < _VoiceWaveModel.dotCount; i++) {
        final double pulse = 0.5 + 0.5 * math.sin(phase - i * 0.9);
        final double radius = _VoiceWaveModel.dotRadius *
            (0.7 + 0.3 * pulse) *
            (0.5 + 0.5 * loadingProgress);
        paint.color =
            _scaleAlpha(color, loadingProgress * (0.4 + 0.6 * pulse));
        canvas.drawCircle(
            Offset(
                size.width / 2 +
                    (i - (_VoiceWaveModel.dotCount - 1) / 2) *
                        _VoiceWaveModel.dotSpacing,
                centerY),
            radius,
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(_VoiceWavePainter oldDelegate) =>
      !identical(oldDelegate.model, model) || oldDelegate.color != color;
}

/// “发送原语音”按钮上的声音图标，按 24×24 绘制，同 android-chat 的 voice_input_ic_sound
class VoiceSoundIconPainter extends CustomPainter {
  const VoiceSoundIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawCircle(const Offset(7, 12), 1.8, Paint()..color = color);
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(10.6, 8.4)
          ..arcToPoint(const Offset(10.6, 15.6),
              radius: const Radius.circular(5.1)),
        stroke);
    canvas.drawPath(
        Path()
          ..moveTo(13.8, 5.2)
          ..arcToPoint(const Offset(13.8, 18.8),
              radius: const Radius.circular(9.6)),
        stroke);
  }

  @override
  bool shouldRepaint(VoiceSoundIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 气泡提示前的圆形感叹号，感叹号镂空透出气泡的颜色，按 22×22 绘制，同 android-chat 的 voice_input_ic_warning
class VoiceWarningIconPainter extends CustomPainter {
  const VoiceWarningIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 22, size.height / 22);
    final Path path = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: const Offset(11, 11), radius: 11))
      ..moveTo(11, 4.8)
      ..cubicTo(11.83, 4.8, 12.47, 5.5, 12.4, 6.33)
      ..lineTo(11.9, 12.93)
      ..cubicTo(11.86, 13.4, 11.47, 13.76, 11, 13.76)
      ..cubicTo(10.53, 13.76, 10.14, 13.4, 10.1, 12.93)
      ..lineTo(9.6, 6.33)
      ..cubicTo(9.53, 5.5, 10.17, 4.8, 11, 4.8)
      ..close()
      ..addOval(Rect.fromCircle(center: const Offset(11, 16.65), radius: 1.45));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(VoiceWarningIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

Color _scaleAlpha(Color color, double factor) =>
    color.withValues(alpha: color.a * factor.clamp(0.0, 1.0));
