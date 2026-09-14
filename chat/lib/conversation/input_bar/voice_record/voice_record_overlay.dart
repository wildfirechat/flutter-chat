import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'voice_record_controller.dart';
import 'voice_record_geometry.dart';
import 'voice_record_painters.dart';
import 'voice_record_style.dart';

/// 按住说话的全屏浮层，界面和动画移植自 android-chat 的 AudioRecorderPanel
///
/// 状态由 [VoiceRecordController] 驱动，每次状态变化时从当前的样子平滑过渡到新状态；
/// 退出动画播放完后调用 [VoiceRecordController.dismissNow]
class VoiceRecordOverlay extends StatefulWidget {
  const VoiceRecordOverlay({
    super.key,
    required this.controller,
    required this.layout,
  });

  final VoiceRecordController controller;
  final VoiceRecordLayout layout;

  @override
  State<VoiceRecordOverlay> createState() => _VoiceRecordOverlayState();
}

class _VoiceRecordOverlayState extends State<VoiceRecordOverlay>
    with TickerProviderStateMixin {
  // 以下曲线对应 android-chat 用到的 Android 插值器
  static const Curve _decelerate = _DecelerateCurve(1.5);
  static const Curve _decelerateFast = _DecelerateCurve(2);
  static const Curve _accelerate = _AccelerateCurve(1);
  static const Curve _accelerateFast = _AccelerateCurve(1.5);
  static const Curve _fastOutSlowIn = Cubic(0.2, 0, 0, 1);

  // ValueAnimator、ViewPropertyAnimator 默认的 AccelerateDecelerateInterpolator
  static const Curve _accelerateDecelerate = Curves.easeInOutSine;

  // 气泡入场：延迟 40ms 后回弹着放大
  static const Duration _enterDuration = Duration(milliseconds: 380);
  static const Curve _enterCurve =
      Interval(40 / 380, 1, curve: _OvershootCurve(1.2));

  // 说话时间太短：延迟 100ms 后在 420ms 内左右晃动
  static const Duration _shakeDuration = Duration(milliseconds: 520);
  static const Curve _shakeCurve =
      Interval(100 / 520, 1, curve: Curves.easeInOutSine);
  static const List<double> _shakeOffsets = [0, -10, 10, -7, 7, -3, 3, 0];

  // 编辑按钮依次升起：第 i 个延迟 140 + 40i 毫秒，用时 300 毫秒（中间的空白也占一个序号）
  static const Duration _editActionsDuration = Duration(milliseconds: 560);

  static const int _maxTextLines = 6;
  static const double _minTextHeight = 30;
  static const double _hintIconSize = 22;
  static const double _hintIconGap = 6;

  // 行高，接近 Android 默认的行距
  static const double _lineHeight = 1.2;

  // 背景的显示程度
  late final AnimationController _background =
      AnimationController(vsync: this);

  // 底部操作区的入场进度
  late final AnimationController _appear = AnimationController(vsync: this);

  // 高亮的目标切换
  late final AnimationController _selection =
      AnimationController(vsync: this, value: 1);
  List<double> _selectionFrom = _selectionOf(VoiceRecordZone.send);
  List<double> _selectionTo = _selectionOf(VoiceRecordZone.send);

  // 气泡形态切换
  late final AnimationController _bubble =
      AnimationController(vsync: this, value: 1);
  VoiceBubbleFrame? _bubbleFrom;
  VoiceBubbleFrame? _bubbleTo;
  VoiceBubbleState? _bubbleToState;

  // 气泡入场、退出时的透明度、缩放和位移
  late final AnimationController _motion = AnimationController(vsync: this);
  _BubbleMotion _motionFrom = _BubbleMotion.hidden;
  _BubbleMotion _motionTo = _BubbleMotion.hidden;
  Curve _motionCurve = Curves.linear;

  late final AnimationController _shake =
      AnimationController(vsync: this, value: 1);

  // 深灰背景上边缘的移动
  late final AnimationController _panel =
      AnimationController(vsync: this, value: 1);
  double _panelFrom = 0;
  double _panelTo = 0;

  late final AnimationController _countDown = AnimationController(vsync: this);
  bool _countDownShown = false;

  late final AnimationController _editActions =
      AnimationController(vsync: this);
  late final AnimationController _editActionsFade =
      AnimationController(vsync: this, value: 1);
  bool _editActionsShown = false;

  // 显示编辑按钮时“发送原语音”是否可用，不可用时半透明
  bool _sendVoiceAvailable = false;

  final FocusNode _textFocusNode = FocusNode();
  final ScrollController _textScrollController = ScrollController();

  // 编辑文字时为软键盘留出的高度
  double _keyboardPadding = 0;

  // 已经处理过的控制器状态，和控制器不一致时播放对应的动画。浮层按刚开始录音时的样子入场
  VoiceRecordStage _stage = VoiceRecordStage.recording;
  VoiceRecordZone _zone = VoiceRecordZone.send;
  VoiceBubbleState _bubbleState = VoiceBubbleState.send;
  bool _textEditable = false;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    final VoiceRecordController controller = widget.controller;
    _panelFrom = _panelTo = widget.layout.recordingPanelTop;
    controller.addListener(_onControllerChanged);
    controller.textController.addListener(_onTextChanged);
    _playEnterAnimation();
    // 插入浮层到浮层第一次构建之间状态可能已经变了，例如很快松手时已经在提示说话时间太短、录音失败时已经在退出
    _applyControllerChanges();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 首次显示，或者字号、语言、主题色变化，气泡直接变成新的尺寸和颜色
    _updateBubbleTarget(animate: false);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.textController.removeListener(_onTextChanged);
    for (final AnimationController controller in [
      _background,
      _appear,
      _selection,
      _bubble,
      _motion,
      _shake,
      _panel,
      _countDown,
      _editActions,
      _editActionsFade,
    ]) {
      controller.dispose();
    }
    _textFocusNode.dispose();
    _textScrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.controller.stage == VoiceRecordStage.idle) {
      // 浮层马上就被移除
      return;
    }
    _applyControllerChanges();
    _updateBubbleTarget(animate: true);
    setState(() {});
  }

  /// 按控制器相对上次处理时的状态变化播放对应的动画
  void _applyControllerChanges() {
    final VoiceRecordController controller = widget.controller;
    if (controller.zone != _zone) {
      _zone = controller.zone;
      _animateSelection(controller.zone);
    }
    if (controller.stage != _stage) {
      final bool enterEditing = _stage == VoiceRecordStage.recording &&
          controller.stage == VoiceRecordStage.editing;
      _stage = controller.stage;
      if (enterEditing) {
        _playEnterEditing();
      }
    }
    if (controller.countDownSeconds != null &&
        !_countDownShown &&
        controller.stage == VoiceRecordStage.recording) {
      _countDownShown = true;
      _countDown.animateTo(1,
          duration: const Duration(milliseconds: 200),
          curve: _accelerateDecelerate);
    }
    if (controller.bubbleState != _bubbleState) {
      _bubbleState = controller.bubbleState;
      if (controller.bubbleState == VoiceBubbleState.tooShort) {
        _shake.value = 0;
        _shake.animateTo(1, duration: _shakeDuration);
      }
    }
    if (controller.textEditable != _textEditable) {
      _textEditable = controller.textEditable;
      if (controller.textEditable) {
        // 输入框变成可编辑之后再获取焦点
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _startEditingText());
      }
    }
    if (controller.isExiting && !_exiting) {
      _exiting = true;
      _playExitAnimation();
    }
  }

  void _onTextChanged() {
    _updateBubbleTarget(animate: true);
    if (!widget.controller.textEditable) {
      // 文字超过最大行数时，滚动到最新识别出的文字
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _textScrollController.hasClients) {
          _textScrollController
              .jumpTo(_textScrollController.position.maxScrollExtent);
        }
      });
    }
    setState(() {});
  }

  /// 识别结果全部返回：弹出软键盘编辑文字，光标放到末尾
  void _startEditingText() {
    final VoiceRecordController controller = widget.controller;
    if (!mounted || !controller.textEditable) {
      return;
    }
    _textFocusNode.requestFocus();
    controller.textController.selection = TextSelection.collapsed(
        offset: controller.textController.text.length);
  }

  void _playEnterAnimation() {
    _background.animateTo(1,
        duration: const Duration(milliseconds: 200),
        curve: _accelerateDecelerate);
    _appear.animateTo(1,
        duration: const Duration(milliseconds: 340), curve: _decelerateFast);
    _animateMotion(
        from: _BubbleMotion.hidden,
        to: _BubbleMotion.shown,
        duration: _enterDuration,
        curve: _enterCurve);
  }

  /// 在“转文字”上松手：倒计时淡出，底部操作区落下，深灰背景升到气泡下方，编辑按钮依次升起
  void _playEnterEditing() {
    _countDown.animateTo(0,
        duration: const Duration(milliseconds: 150),
        curve: _accelerateDecelerate);
    _appear.animateTo(0,
        duration: const Duration(milliseconds: 220), curve: _accelerateFast);
    _panelFrom = _panelTop;
    _panelTo = widget.layout.editPanelTop(_keyboardPadding);
    _panel.value = 0;
    _panel.animateTo(1, duration: const Duration(milliseconds: 360));
    _sendVoiceAvailable = widget.controller.isVoiceAvailable;
    _editActionsShown = true;
    _editActions.value = 0;
    _editActions.animateTo(1, duration: _editActionsDuration);
  }

  void _playExitAnimation() {
    _textFocusNode.unfocus();
    // 气泡停在当前的样子淡出
    _bubble.stop();
    _appear.animateTo(0,
        duration: const Duration(milliseconds: 220), curve: _accelerateFast);
    _animateMotion(
        to: _BubbleMotion.dismissed,
        duration: const Duration(milliseconds: 180),
        curve: _accelerate);
    _countDown.animateTo(0,
        duration: const Duration(milliseconds: 150),
        curve: _accelerateDecelerate);
    _editActionsFade.animateTo(0,
        duration: const Duration(milliseconds: 150),
        curve: _accelerateDecelerate);
    _background
        .animateTo(0,
            duration: const Duration(milliseconds: 240),
            curve: _accelerateDecelerate)
        .then((_) {
      if (mounted && widget.controller.isExiting) {
        widget.controller.dismissNow();
      }
    });
  }

  void _animateSelection(VoiceRecordZone zone) {
    _selectionFrom = _selectionValues;
    _selectionTo = _selectionOf(zone);
    _selection.value = 0;
    _selection.animateTo(1, duration: const Duration(milliseconds: 220));
  }

  void _animateMotion({
    _BubbleMotion? from,
    required _BubbleMotion to,
    required Duration duration,
    required Curve curve,
  }) {
    _motionFrom = from ?? _bubbleMotion;
    _motionTo = to;
    _motionCurve = curve;
    _motion.value = 0;
    _motion.animateTo(1, duration: duration);
  }

  /// 气泡从当前的样子过渡到当前状态对应的形态；形态不变、内容变化时（例如识别出了新的文字）用较短的时间改变高度
  void _updateBubbleTarget({required bool animate}) {
    final VoiceRecordController controller = widget.controller;
    if (controller.isExiting && _bubbleTo != null) {
      // 退出时气泡保持当前的样子
      return;
    }
    final VoiceBubbleFrame target = widget.layout.bubbleFrame(
      state: controller.bubbleState,
      asrFinished: controller.asrFinished,
      colors: _bubbleColors,
      measureHeight: _measureBubbleHeight,
      measureHintWidth: _measureHintWidth,
    );
    if (target == _bubbleTo) {
      return;
    }
    if (!animate || _bubbleTo == null) {
      _bubble.stop();
      _bubbleFrom = _bubbleTo = target;
      _bubbleToState = controller.bubbleState;
      return;
    }
    final bool stateChanged = controller.bubbleState != _bubbleToState;
    _bubbleFrom = _bubbleFrame;
    _bubbleTo = target;
    _bubbleToState = controller.bubbleState;
    _bubble.value = 0;
    _bubble.animateTo(1,
        duration: Duration(milliseconds: stateChanged ? 320 : 180));
  }

  VoiceBubbleFrame get _bubbleFrame => VoiceBubbleFrame.lerp(
      _bubbleFrom!, _bubbleTo!, _fastOutSlowIn.transform(_bubble.value));

  _BubbleMotion get _bubbleMotion => _BubbleMotion.lerp(
      _motionFrom, _motionTo, _motionCurve.transform(_motion.value));

  List<double> get _selectionValues {
    final double t = _decelerate.transform(_selection.value);
    return [
      for (int i = 0; i < _selectionTo.length; i++)
        ui.lerpDouble(_selectionFrom[i], _selectionTo[i], t)!,
    ];
  }

  double get _panelTop => ui.lerpDouble(
      _panelFrom, _panelTo, _fastOutSlowIn.transform(_panel.value))!;

  double get _shakeOffset {
    final double position = math.max(0.0, _shakeCurve.transform(_shake.value)) *
        (_shakeOffsets.length - 1);
    final int index = math.min(position.floor(), _shakeOffsets.length - 2);
    return ui.lerpDouble(
        _shakeOffsets[index], _shakeOffsets[index + 1], position - index)!;
  }

  static List<double> _selectionOf(VoiceRecordZone zone) => [
        for (final VoiceRecordZone value in VoiceRecordZone.values)
          value == zone ? 1.0 : 0.0,
      ];

  VoiceBubbleColors get _bubbleColors => VoiceBubbleColors(
      normal: context.colors.accent, alert: context.colors.danger);

  /// 浮层的文字样式。字体跟随主题，其余属性都显式指定：输入框会把主题的默认样式合并进来，
  /// 行高、字间距不一致的话，测量出的气泡高度就和实际显示的对不上
  TextStyle _textStyle(double fontSize, Color color) {
    final TextStyle base =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return TextStyle(
      fontFamily: base.fontFamily,
      fontFamilyFallback: base.fontFamilyFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: _lineHeight,
      color: color,
    );
  }

  String? get _hintText {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return switch (widget.controller.hint) {
      VoiceBubbleHint.tooShort => l10n.voiceRecordTooShort,
      VoiceBubbleHint.noText => l10n.voiceRecordNoText,
      VoiceBubbleHint.recognizeFailed => l10n.voiceRecordRecognizeFailed,
      null => null,
    };
  }

  /// 提示的图标和文字同色：说话时间太短时气泡是主色调，没有识别到文字时气泡是红色
  Color get _hintColor {
    final VoiceBubbleColors colors = _bubbleColors;
    return widget.controller.hint == VoiceBubbleHint.tooShort
        ? colors.content
        : colors.alertContent;
  }

  /// 气泡按 [width] 宽度显示当前文字时的高度
  double _measureBubbleHeight(double width, double textBottomMargin) {
    const EdgeInsets padding = VoiceRecordLayout.bubblePadding;
    final double contentWidth = math.max(0.0, width - padding.horizontal);
    final VoiceRecordController controller = widget.controller;
    final String text = controller.textController.text.isEmpty &&
            controller.showsRecognizeFailedInText
        ? AppLocalizations.of(context)!.voiceRecordRecognizeFailed
        : controller.textController.text;
    final TextStyle style =
        _textStyle(VoiceRecordTextSize.bubbleText, _bubbleColors.content);
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: _maxTextLines,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
    )..layout(maxWidth: contentWidth);
    final double textHeight =
        math.max(_minTextHeight, painter.height) + textBottomMargin;
    painter.dispose();
    return padding.top +
        math.max(textHeight, _measureHint(contentWidth).height) +
        padding.bottom;
  }

  /// 气泡完整显示提示所需的宽度，不超过 [maxWidth]
  double _measureHintWidth(double maxWidth) {
    final double horizontalPadding =
        VoiceRecordLayout.bubblePadding.horizontal;
    return _measureHint(maxWidth - horizontalPadding).width +
        horizontalPadding;
  }

  /// 提示（图标加文字）按最大宽度 [maxWidth] 显示时的尺寸
  Size _measureHint(double maxWidth) {
    final String? hint = _hintText;
    if (hint == null) {
      return Size.zero;
    }
    final TextPainter painter = TextPainter(
      text: TextSpan(
          text: hint,
          style: _textStyle(VoiceRecordTextSize.bubbleHint, _hintColor)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
    )..layout(maxWidth: math.max(0.0, maxWidth - _hintIconSize - _hintIconGap));
    final Size size = Size(_hintIconSize + _hintIconGap + painter.width,
        math.max(_hintIconSize, painter.height));
    painter.dispose();
    return size;
  }

  void _syncKeyboardPadding(double padding) {
    if (padding == _keyboardPadding) {
      return;
    }
    _keyboardPadding = padding;
    if (widget.controller.stage == VoiceRecordStage.editing) {
      // 深灰背景跟着气泡移动
      _panel.stop();
      _panelFrom = _panelTo = widget.layout.editPanelTop(padding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final VoiceRecordController controller = widget.controller;
    final VoiceRecordLayout layout = widget.layout;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    _syncKeyboardPadding(controller.stage == VoiceRecordStage.editing
        ? layout.keyboardPadding(MediaQuery.viewInsetsOf(context).bottom)
        : 0);
    final int? countDownSeconds = controller.countDownSeconds;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 拦下其他手指的触摸，按住按钮的那根手指不受影响
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              child: AnimatedBuilder(
                animation: Listenable.merge([_background, _panel]),
                builder: (context, _) => CustomPaint(
                  painter: VoiceInputBackgroundPainter(
                    progress: _background.value,
                    stageLeft: layout.stageLeft,
                    stageRight: layout.stageRight,
                    panelTop: _panelTop,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_appear, _selection]),
                  builder: (context, _) => CustomPaint(
                    painter: VoiceRecordBottomPainter(
                      layout: layout,
                      labels: VoiceRecordBottomLabels(
                        voice: l10n.voiceRecordVoice,
                        releaseToSend: l10n.voiceRecordReleaseToSend,
                        cancel: l10n.cancel,
                        releaseToCancel: l10n.voiceRecordReleaseToCancel,
                        slideToText: l10n.voiceRecordSlideToText,
                        releaseToEdit: l10n.voiceRecordReleaseToEdit,
                      ),
                      textStyle: _textStyle(VoiceRecordTextSize.pillLabel,
                          VoiceRecordPalette.pillLabel),
                      textScaler: MediaQuery.textScalerOf(context),
                      speechToTextEnabled: controller.speechToTextEnabled,
                      appear: _appear.value,
                      selection: _selectionValues,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 编辑文字时弹出软键盘，气泡和按钮顶到软键盘上方
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: _keyboardPadding),
              child: Stack(
                children: [
                  if (countDownSeconds != null)
                    _buildCountDown(l10n, countDownSeconds),
                  _buildBubble(controller, l10n),
                  if (_editActionsShown) _buildEditActions(controller, l10n),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountDown(AppLocalizations l10n, int seconds) {
    final VoiceRecordLayout layout = widget.layout;
    return Positioned(
      left: layout.stageLeft,
      width: layout.stageWidth,
      bottom: layout.countDownBottomMargin,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _countDown,
          child: Text(
            l10n.voiceRecordCountDown(seconds),
            textAlign: TextAlign.center,
            style: _textStyle(
                VoiceRecordTextSize.countDown, VoiceRecordPalette.countDown),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(VoiceRecordController controller, AppLocalizations l10n) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bubble, _motion, _shake]),
      builder: (context, _) {
        final VoiceBubbleFrame frame = _bubbleFrame;
        final _BubbleMotion motion = _bubbleMotion;
        return Positioned(
          left: frame.left,
          bottom: widget.layout.bubbleBottomMargin,
          width: frame.width,
          height: frame.height,
          child: Transform(
            // 缩放中心在气泡底部中间
            alignment: Alignment.bottomCenter,
            transform: Matrix4.translationValues(
                _shakeOffset, motion.offsetY, 0)
              ..multiply(Matrix4.diagonal3Values(motion.scale, motion.scale, 1)),
            child: Opacity(
              opacity: motion.opacity.clamp(0.0, 1.0),
              child: CustomPaint(
                painter:
                    VoiceBubblePainter(color: frame.color, tailX: frame.tailX),
                child: _buildBubbleContent(controller, l10n, frame),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBubbleContent(VoiceRecordController controller,
      AppLocalizations l10n, VoiceBubbleFrame frame) {
    const EdgeInsets padding = VoiceRecordLayout.bubblePadding;
    return Stack(
      children: [
        Positioned(
          left: padding.left,
          top: padding.top,
          right: padding.right,
          child: Opacity(
            opacity: frame.textAlpha.clamp(0.0, 1.0),
            child: _buildTextField(controller, l10n),
          ),
        ),
        Positioned(
          left: padding.left,
          top: padding.top,
          right: padding.right,
          bottom: padding.bottom,
          child: IgnorePointer(
            child: Opacity(
              opacity: frame.hintAlpha.clamp(0.0, 1.0),
              // 提示淡入时轻微上浮
              child: Transform.translate(
                offset: Offset(0, (1 - frame.hintAlpha) * 6),
                child: Center(child: _buildHint()),
              ),
            ),
          ),
        ),
        Positioned(
          left: frame.waveCenterX - frame.waveWidth / 2,
          top: frame.waveCenterY - frame.waveHeight / 2,
          width: frame.waveWidth,
          height: frame.waveHeight,
          child: IgnorePointer(
            child: Opacity(
              opacity: frame.waveAlpha.clamp(0.0, 1.0),
              child: RepaintBoundary(
                child: VoiceWaveView(
                  level: controller.level,
                  loading: controller.waveLoading,
                  color: frame.waveColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
      VoiceRecordController controller, AppLocalizations l10n) {
    final Color content = _bubbleColors.content;
    final TextStyle style = _textStyle(VoiceRecordTextSize.bubbleText, content);
    final bool editable = controller.textEditable;
    return TextSelectionTheme(
      data: TextSelectionThemeData(
        cursorColor: content,
        selectionColor: content.withValues(alpha: 0.3),
        selectionHandleColor: content,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minTextHeight),
        child: TextField(
          controller: controller.textController,
          focusNode: _textFocusNode,
          scrollController: _textScrollController,
          readOnly: !editable,
          canRequestFocus: editable,
          showCursor: editable,
          enableInteractiveSelection: editable,
          keyboardType: TextInputType.multiline,
          minLines: 1,
          maxLines: _maxTextLines,
          style: style,
          strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
          cursorColor: content,
          cursorWidth: 2,
          decoration: InputDecoration.collapsed(
            hintText: controller.showsRecognizeFailedInText
                ? l10n.voiceRecordRecognizeFailed
                : null,
            hintStyle: style.copyWith(color: content.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }

  Widget _buildHint() {
    final String? hint = _hintText;
    if (hint == null) {
      return const SizedBox.shrink();
    }
    final Color color = _hintColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size.square(_hintIconSize),
          painter: VoiceWarningIconPainter(color),
        ),
        const SizedBox(width: _hintIconGap),
        Flexible(
          child: Text(
            hint,
            maxLines: 2,
            style: _textStyle(VoiceRecordTextSize.bubbleHint, color),
          ),
        ),
      ],
    );
  }

  Widget _buildEditActions(
      VoiceRecordController controller, AppLocalizations l10n) {
    final VoiceRecordLayout layout = widget.layout;
    final TextStyle labelStyle = _textStyle(
        VoiceRecordTextSize.actionLabel, VoiceRecordPalette.actionLabel);
    return Positioned(
      left: layout.stageLeft,
      width: layout.stageWidth,
      bottom: layout.editActionsBottomMargin,
      child: FadeTransition(
        opacity: _editActionsFade,
        child: IgnorePointer(
          ignoring: controller.stage != VoiceRecordStage.editing,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _staggered(
                  index: 0,
                  child: _VoiceCircleAction(
                    label: l10n.cancel,
                    labelStyle: labelStyle,
                    icon: const Icon(Icons.close,
                        size: 24, color: VoiceRecordPalette.circleButtonIcon),
                    onTap: controller.cancelEditing,
                  ),
                ),
                const SizedBox(width: 10),
                _staggered(
                  index: 1,
                  opacity: _sendVoiceAvailable ? 1 : 0.4,
                  child: _VoiceCircleAction(
                    label: l10n.voiceRecordSendVoice,
                    labelStyle: labelStyle,
                    icon: const CustomPaint(
                      size: Size.square(26),
                      painter: VoiceSoundIconPainter(
                          VoiceRecordPalette.circleButtonIcon),
                    ),
                    onTap: controller.isVoiceAvailable
                        ? controller.sendVoiceFromEditing
                        : null,
                  ),
                ),
                const Spacer(),
                _staggered(
                  index: 3,
                  child: _VoiceSendButton(
                    label: l10n.send,
                    textStyle: _textStyle(VoiceRecordTextSize.sendButton,
                        VoiceRecordPalette.sendButtonText),
                    onTap: controller.canSendText ? controller.sendText : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 第 [index] 个编辑按钮：延迟一段时间后淡入到 [opacity] 并升起
  Widget _staggered(
      {required int index, double opacity = 1, required Widget child}) {
    final Curve curve = Interval((140 + 40 * index) / 560,
        (440 + 40 * index) / 560,
        curve: _decelerateFast);
    return AnimatedBuilder(
      animation: _editActions,
      builder: (context, child) {
        final double t = curve.transform(_editActions.value);
        return Opacity(
          opacity: opacity * t,
          child: Transform.translate(
              offset: Offset(0, 28 * (1 - t)), child: child),
        );
      },
      child: child,
    );
  }
}

/// 编辑文字时底部的圆形按钮，下方是文字
class _VoiceCircleAction extends StatefulWidget {
  const _VoiceCircleAction({
    required this.label,
    required this.labelStyle,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final TextStyle labelStyle;
  final Widget icon;

  /// 为 null 时不可点击
  final VoidCallback? onTap;

  @override
  State<_VoiceCircleAction> createState() => _VoiceCircleActionState();
}

class _VoiceCircleActionState extends State<_VoiceCircleAction> {
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant _VoiceCircleAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null) {
      _pressed = false;
    }
  }

  void _setPressed(bool pressed) {
    if (_pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: SizedBox(
          width: 96,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTapDown: enabled ? (_) => _setPressed(true) : null,
                onTapUp: enabled ? (_) => _setPressed(false) : null,
                onTapCancel: enabled ? () => _setPressed(false) : null,
                onTap: widget.onTap,
                child: Container(
                  width: 66,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _pressed
                        ? VoiceRecordPalette.circleButtonPressed
                        : VoiceRecordPalette.circleButton,
                  ),
                  child: widget.icon,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: widget.labelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 编辑文字时的“发送”按钮
class _VoiceSendButton extends StatefulWidget {
  const _VoiceSendButton({
    required this.label,
    required this.textStyle,
    required this.onTap,
  });

  final String label;
  final TextStyle textStyle;

  /// 为 null 时不可点击
  final VoidCallback? onTap;

  @override
  State<_VoiceSendButton> createState() => _VoiceSendButtonState();
}

class _VoiceSendButtonState extends State<_VoiceSendButton> {
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant _VoiceSendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null) {
      _pressed = false;
    }
  }

  void _setPressed(bool pressed) {
    if (_pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final Color background = !enabled
        ? VoiceRecordPalette.sendButtonDisabled
        : _pressed
            ? VoiceRecordPalette.sendButtonPressed
            : VoiceRecordPalette.sendButton;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: widget.onTap,
        child: Container(
          width: 124,
          height: 74,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(37),
          ),
          child: Text(
            widget.label,
            style: widget.textStyle.copyWith(
                color: enabled
                    ? VoiceRecordPalette.sendButtonText
                    : VoiceRecordPalette.sendButtonTextDisabled),
          ),
        ),
      ),
    );
  }
}

/// 气泡整体的透明度、缩放和纵向位移
@immutable
class _BubbleMotion {
  const _BubbleMotion(this.opacity, this.scale, this.offsetY);

  /// 入场之前
  static const _BubbleMotion hidden = _BubbleMotion(0, 0.6, 24);
  static const _BubbleMotion shown = _BubbleMotion(1, 1, 0);

  /// 退出之后
  static const _BubbleMotion dismissed = _BubbleMotion(0, 0.85, 0);

  final double opacity;
  final double scale;
  final double offsetY;

  static _BubbleMotion lerp(_BubbleMotion from, _BubbleMotion to, double t) =>
      _BubbleMotion(
        ui.lerpDouble(from.opacity, to.opacity, t)!,
        ui.lerpDouble(from.scale, to.scale, t)!,
        ui.lerpDouble(from.offsetY, to.offsetY, t)!,
      );
}

/// Android 的 DecelerateInterpolator
class _DecelerateCurve extends Curve {
  const _DecelerateCurve(this.factor);

  final double factor;

  @override
  double transformInternal(double t) =>
      1 - math.pow(1 - t, 2 * factor).toDouble();
}

/// Android 的 AccelerateInterpolator
class _AccelerateCurve extends Curve {
  const _AccelerateCurve(this.factor);

  final double factor;

  @override
  double transformInternal(double t) => math.pow(t, 2 * factor).toDouble();
}

/// Android 的 OvershootInterpolator，结果会超过 1，所以不能直接交给 AnimationController（它会截断到 0~1）
class _OvershootCurve extends Curve {
  const _OvershootCurve(this.tension);

  final double tension;

  @override
  double transformInternal(double t) {
    final double x = t - 1;
    return x * x * ((tension + 1) * x + tension) + 1;
  }
}
