import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:chat/asr/asr_error.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/utils/show_toast.dart';
import 'voice_input_controller.dart';

/// 移动端输入框右下角的语音输入按钮，和 android-chat 一致。PC 端把 [VoiceInputIcon] 放进工具条按钮
class VoiceInputButton extends StatelessWidget {
  const VoiceInputButton({super.key, required this.controller});

  final VoiceInputController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.toggle(
            onError: (error) => showVoiceInputError(l10n, error)),
        child: SizedBox.square(
          dimension: 38,
          child: Center(
            child: VoiceInputIcon(
              controller: controller,
              style: VoiceInputIconStyle.mic,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// 语音输入出错时的提示，文案和 android-chat、vue-pc-chat 一致：「语音识别错误: xxx」
void showVoiceInputError(AppLocalizations l10n, AsrError error) {
  final String message = switch (error.kind) {
    AsrErrorKind.noPermission => l10n.noMicrophonePermission,
    AsrErrorKind.notConfigured => l10n.voiceInputError(l10n.asrNotConfigured),
    AsrErrorKind.recordFailed =>
      l10n.voiceInputError(l10n.recordFailed(error.detail ?? '')),
    AsrErrorKind.authCodeFailed =>
      l10n.voiceInputError(l10n.asrGetAuthCodeFailed(error.detail ?? '')),
    AsrErrorKind.unauthorized => l10n.voiceInputError(l10n.asrUnauthorized),
    AsrErrorKind.connectFailed =>
      l10n.voiceInputError(l10n.asrConnectFailed(error.detail ?? '')),
    AsrErrorKind.connectTimeout =>
      l10n.voiceInputError(l10n.asrConnectTimeout),
    AsrErrorKind.disconnected => l10n.voiceInputError(l10n.asrDisconnected),
  };
  showToast(msg: message);
}

/// 语音输入图标的样式
enum VoiceInputIconStyle {
  /// 麦克风，同 android-chat 输入框里的语音输入图标，用于移动端
  mic,

  /// 麦克风加三行文字，和「发送语音」的图标区分开，同 vue-pc-chat，用于 PC 端工具条
  micWithText,
}

/// 语音输入图标，随 [VoiceInputController.state] 变化，动画同 android-chat：
/// 开始录音时渐变成主题色，然后呼吸闪烁；停止录音、等待剩余识别结果时停止闪烁，保持主题色；识别结束后渐变回原来的颜色。
/// 只负责显示，点击由外层处理。
class VoiceInputIcon extends StatefulWidget {
  const VoiceInputIcon({
    super.key,
    required this.controller,
    required this.style,
    this.size = 22,
  });

  final VoiceInputController controller;
  final VoiceInputIconStyle style;
  final double size;

  @override
  State<VoiceInputIcon> createState() => _VoiceInputIconState();
}

class _VoiceInputIconState extends State<VoiceInputIcon>
    with TickerProviderStateMixin {
  static const String _micAsset = 'assets/images/input/voice_input_mic.png';

  // Android 的 DecelerateInterpolator()
  static const Curve _transitionCurve = Curves.easeOutQuad;

  // 颜色渐变完再开始闪烁
  static const Duration _pulseDelay = Duration(milliseconds: 200);

  // 从 [_tintFrom]、[_opacityFrom] 渐变到 [_tintTo]、完全不透明
  late final AnimationController _transition =
      AnimationController(vsync: this, value: 1);

  // 呼吸闪烁，0 完全不透明，1 最暗
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));

  // 图标混合主题色的比例
  double _tintFrom = 0;
  double _tintTo = 0;
  double _opacityFrom = 1;
  Timer? _pulseTimer;
  late VoiceInputState _state;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChanged);
    _syncWithoutAnimation();
  }

  @override
  void didUpdateWidget(covariant VoiceInputIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    // PC 端切换会话时输入栏复用，controller 换成新会话的
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onStateChanged);
      widget.controller.addListener(_onStateChanged);
      _syncWithoutAnimation();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    _pulseTimer?.cancel();
    _transition.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _syncWithoutAnimation() {
    _state = widget.controller.state;
    _pulseTimer?.cancel();
    _pulse.stop();
    _pulse.value = 0;
    _transition.value = 1;
    _tintFrom = _tintTo = _state == VoiceInputState.idle ? 0 : 1;
    _opacityFrom = 1;
    if (_state == VoiceInputState.recording) {
      _pulse.repeat(reverse: true);
    }
  }

  void _onStateChanged() {
    final VoiceInputState state = widget.controller.state;
    if (state == _state) {
      return;
    }
    _state = state;
    switch (state) {
      case VoiceInputState.recording:
        _animateTint(1, const Duration(milliseconds: 200));
        _pulseTimer = Timer(_pulseDelay, () => _pulse.repeat(reverse: true));
      case VoiceInputState.finishing:
        _animateTint(1, const Duration(milliseconds: 200));
      case VoiceInputState.idle:
        _animateTint(0, const Duration(milliseconds: 250));
    }
  }

  /// 从当前状态把混合主题色的比例渐变到 [tint]，同时停止闪烁、透明度恢复到 1
  void _animateTint(double tint, Duration duration) {
    final double opacity = _opacity;
    _tintFrom = _tint;
    _tintTo = tint;
    _opacityFrom = opacity;
    _pulseTimer?.cancel();
    _pulse.stop();
    _pulse.value = 0;
    _transition.value = 0;
    _transition.animateTo(1, duration: duration);
  }

  double get _transitionProgress => _transitionCurve.transform(_transition.value);

  double get _tint =>
      ui.lerpDouble(_tintFrom, _tintTo, _transitionProgress)!;

  double get _opacity => _pulse.isAnimating
      // 正弦缓动，明暗交替柔和，同 android-chat 的 AccelerateDecelerateInterpolator
      ? 1 - 0.7 * Curves.easeInOutSine.transform(_pulse.value)
      : ui.lerpDouble(_opacityFrom, 1, _transitionProgress)!;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return AnimatedBuilder(
      animation: Listenable.merge([_transition, _pulse]),
      builder: (context, _) {
        final double tint = _tint.clamp(0.0, 1.0);
        final Widget icon = switch (widget.style) {
          VoiceInputIconStyle.mic => Image.asset(
              _micAsset,
              width: widget.size,
              height: widget.size,
              // SRC_ATOP 混合：主题色的透明度就是混合比例，图标形状和抗锯齿边缘不变（同 android-chat）
              color: tint > 0
                  ? colors.accent.withValues(alpha: colors.accent.a * tint)
                  : null,
              colorBlendMode: BlendMode.srcATop,
            ),
          VoiceInputIconStyle.micWithText => CustomPaint(
              size: Size.square(widget.size),
              painter: _VoiceInputGlyphPainter(
                  Color.lerp(colors.iconSecondary, colors.accent, tint)!),
            ),
        };
        return Opacity(opacity: _opacity.clamp(0.0, 1.0), child: icon);
      },
    );
  }
}

/// 麦克风加三行文字，和「发送语音」的图标区分开。图形同 vue-pc-chat 的语音输入图标，按 24×24 绘制
class _VoiceInputGlyphPainter extends CustomPainter {
  _VoiceInputGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final Paint fill = Paint()..color = color;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // 麦克风
    canvas.drawRRect(
        RRect.fromLTRBR(3, 2, 10, 14, const Radius.circular(3.5)), fill);
    canvas.drawArc(
        Rect.fromCircle(center: const Offset(6.5, 10.5), radius: 5.25),
        0,
        math.pi,
        false,
        stroke);
    canvas.drawLine(const Offset(6.5, 15.75), const Offset(6.5, 20), stroke);

    // 文字行
    for (final (double top, double width) in const [
      (5.0, 9.0),
      (10.4, 9.0),
      (15.8, 6.0),
    ]) {
      canvas.drawRRect(
          RRect.fromLTRBR(
              14, top, 14 + width, top + 2.2, const Radius.circular(1.1)),
          fill);
    }
  }

  @override
  bool shouldRepaint(_VoiceInputGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
