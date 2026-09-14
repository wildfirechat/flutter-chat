import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'voice_record_style.dart';

/// 按住说话时手指所在的目标
enum VoiceRecordZone {
  /// 底部弧形的“松开 发送”区域
  send,

  /// 左上方的“取消”
  cancel,

  /// 右上方的“转文字”
  text,
}

/// 气泡的形态
enum VoiceBubbleState {
  /// 松开发送：主色调，中间是声波
  send,

  /// 取消：缩成红色的小方块，移到“取消”上方
  cancel,

  /// 转文字：展开成整行宽度，边说边显示识别出的文字
  text,

  /// 在“转文字”上松手后编辑文字
  edit,

  /// 没有识别到文字：红色的提示
  noText,

  /// 说话时间太短：保持松开发送时的样子，声波换成提示
  tooShort,
}

/// 按住说话浮层的布局，坐标都相对于浮层。数值移植自 android-chat 的 AudioRecorderPanel 和 VoiceRecordBottomView
///
/// 按下按钮时根据浮层尺寸、会话界面和按钮的位置计算一次
@immutable
class VoiceRecordLayout {
  /// [stage] 是会话界面的位置，[buttonTop] 是按住说话按钮上边缘的 y 坐标
  factory VoiceRecordLayout({
    required Size size,
    required Rect stage,
    required double buttonTop,
  }) {
    // 操作区只覆盖会话界面，双栏时不会延伸到左边
    double stageLeft = math.max(0.0, stage.left);
    double stageWidth = math.min(size.width - stageLeft, stage.width);
    if (stageWidth <= 0) {
      stageLeft = 0;
      stageWidth = size.width;
    }
    return VoiceRecordLayout._(
      size: size,
      stageLeft: stageLeft,
      stageWidth: stageWidth,
      // 底部弧形区域要盖住按住说话的按钮，手指按下时就在“松开 发送”区域内
      arcTop: math.min(size.height - 110, buttonTop - 16),
    );
  }

  const VoiceRecordLayout._({
    required this.size,
    required this.stageLeft,
    required this.stageWidth,
    required this.arcTop,
  });

  /// 气泡底部尖角的高度
  static const double tailHeight = 8;

  /// 气泡的内边距，底部包含尖角
  static const EdgeInsets bubblePadding = EdgeInsets.fromLTRB(20, 18, 20, 26);

  /// 两条弧形按钮之间的间隙
  static const double pillGap = 22;

  /// 浮层的尺寸
  final Size size;

  /// 操作区（会话界面）的左边界和宽度
  final double stageLeft;
  final double stageWidth;

  /// 底部弧形区域最高点的 y 坐标
  final double arcTop;

  double get stageRight => stageLeft + stageWidth;

  double get centerX => stageLeft + stageWidth / 2;

  /// 底部弧形区域是圆心在底部中间下方的大圆
  double get arcRadius => stageWidth * 1.68;

  double get arcCenterY => arcTop + arcRadius;

  /// 两条弧形按钮的粗细，中线在同一个更大的圆上
  double get pillThickness => (stageWidth * 0.17).clamp(56.0, 72.0);

  double get pillRadius => stageWidth * 1.72;

  double get pillCenterY => arcTop - 16 - pillThickness / 2 + pillRadius;

  /// 按钮文字中心到中线的水平距离
  double get labelOffsetX => math.min(stageWidth * 0.29, 170.0);

  /// 按钮文字的最大宽度，超出时缩小字号
  double get maxLabelWidth => math.max(
      48.0,
      2 *
          math.min(labelOffsetX - pillGap / 2 - 12,
              stageWidth / 2 - 8 - labelOffsetX));

  /// 弧形按钮上边缘最高点的 y 坐标
  double get pillTop => pillCenterY - pillRadius - pillThickness / 2;

  /// “取消”按钮文字中心的 x 坐标
  double get cancelCenterX => centerX - labelOffsetX;

  /// 录音时深灰背景完全不透明处的 y 坐标，从弧形按钮处开始
  double get recordingPanelTop => pillTop + 18;

  /// 气泡下边缘到浮层底部的距离：气泡的尖角固定在按钮上方，内容变多时向上长高
  double get bubbleBottomMargin => size.height - math.max(160.0, pillTop - 141);

  /// 编辑文字时底部按钮到浮层底部的距离
  double get editActionsBottomMargin =>
      math.max(16.0, size.height - arcTop - 20);

  /// 倒计时到浮层底部的距离，在气泡下方
  double get countDownBottomMargin => bubbleBottomMargin - 44;

  /// 编辑文字时为软键盘留出的高度，把气泡和按钮顶到软键盘上方
  double keyboardPadding(double keyboardHeight) => keyboardHeight > 0
      ? math.max(0.0, keyboardHeight - editActionsBottomMargin + 12)
      : 0;

  /// 编辑文字时深灰背景完全不透明处的 y 坐标，在气泡下边缘稍上方
  double editPanelTop(double keyboardPadding) =>
      size.height - keyboardPadding - bubbleBottomMargin - tailHeight - 5;

  /// 手指所在的目标
  VoiceRecordZone zoneAt(Offset position,
      {required bool speechToTextEnabled}) {
    final double dx = position.dx - centerX;
    if (dx.abs() < arcRadius &&
        position.dy >=
            arcCenterY - math.sqrt(arcRadius * arcRadius - dx * dx)) {
      return VoiceRecordZone.send;
    }
    return speechToTextEnabled && position.dx >= centerX
        ? VoiceRecordZone.text
        : VoiceRecordZone.cancel;
  }

  /// 气泡 [state] 形态的位置、大小和内容
  ///
  /// [measureHeight] 测量气泡按指定宽度和文字下边距显示当前文字时的高度；
  /// [measureHintWidth] 测量气泡完整显示提示所需的宽度，不超过指定的最大宽度
  VoiceBubbleFrame bubbleFrame({
    required VoiceBubbleState state,
    required bool asrFinished,
    required VoiceBubbleColors colors,
    required double Function(double width, double textBottomMargin)
        measureHeight,
    required double Function(double maxWidth) measureHintWidth,
  }) {
    const double compactHeight = 78;
    final double maxWidth = stageWidth - 32;
    final double sendWidth =
        math.min(maxWidth, math.max(160.0, stageWidth * 0.475));
    switch (state) {
      case VoiceBubbleState.cancel:
        // 缩成红色的小方块，移到“取消”上方
        const double width = compactHeight;
        final double left =
            math.max(stageLeft + 16, cancelCenterX - width / 2);
        return VoiceBubbleFrame(
          left: left,
          width: width,
          height: compactHeight + tailHeight,
          tailX: cancelCenterX - left,
          color: colors.alert,
          waveColor: colors.alertContent,
          waveWidth: 34,
          waveHeight: 16,
          waveCenterX: width / 2,
          waveCenterY: compactHeight / 2,
          waveAlpha: 1,
          textAlpha: 0,
          hintAlpha: 0,
          textBottomMargin: 20,
        );
      case VoiceBubbleState.text:
      case VoiceBubbleState.edit:
      case VoiceBubbleState.noText:
        // 展开成整行宽度显示文字，声波缩小到右下角，识别完成后消失；没有识别到文字时变成红色的提示
        final bool noText = state == VoiceBubbleState.noText;
        final bool showWave = state == VoiceBubbleState.text ||
            (state == VoiceBubbleState.edit && !asrFinished);
        final double left = stageLeft + 16;
        final double textBottomMargin = showWave ? 20 : 0;
        final double height = measureHeight(maxWidth, textBottomMargin);
        return VoiceBubbleFrame(
          left: left,
          width: maxWidth,
          height: height,
          // 和微信一样，整行宽度的气泡尖角固定在同一个位置，转文字、编辑、没有识别到文字之间切换时不动
          tailX: stageLeft + stageWidth * 0.755 - left,
          color: noText ? colors.alert : colors.normal,
          waveColor: noText ? colors.alertContent : colors.content,
          waveWidth: 34,
          waveHeight: 16,
          waveCenterX: maxWidth - 20 - 34 / 2,
          waveCenterY: height - tailHeight - 18,
          waveAlpha: showWave ? 1 : 0,
          textAlpha: noText ? 0 : 1,
          hintAlpha: noText ? 1 : 0,
          textBottomMargin: textBottomMargin,
        );
      case VoiceBubbleState.tooShort:
        // 保持松开发送时的样子，声波换成提示，提示放不下时加宽
        final double width =
            math.min(maxWidth, math.max(sendWidth, measureHintWidth(maxWidth)));
        return VoiceBubbleFrame(
          left: stageLeft + (stageWidth - width) / 2,
          width: width,
          height: compactHeight + tailHeight,
          tailX: width / 2,
          color: colors.normal,
          waveColor: colors.content,
          waveWidth: sendWidth * 0.46,
          waveHeight: 20,
          waveCenterX: width / 2,
          waveCenterY: compactHeight / 2,
          waveAlpha: 0,
          textAlpha: 0,
          hintAlpha: 1,
          textBottomMargin: 20,
        );
      case VoiceBubbleState.send:
        return VoiceBubbleFrame(
          left: stageLeft + (stageWidth - sendWidth) / 2,
          width: sendWidth,
          height: compactHeight + tailHeight,
          tailX: sendWidth / 2,
          color: colors.normal,
          waveColor: colors.content,
          waveWidth: sendWidth * 0.46,
          waveHeight: 20,
          waveCenterX: sendWidth / 2,
          waveCenterY: compactHeight / 2,
          waveAlpha: 1,
          textAlpha: 0,
          hintAlpha: 0,
          textBottomMargin: 20,
        );
    }
  }
}

/// 气泡某一形态的位置、大小和内容。[left] 相对于浮层，声波和尖角的坐标相对于气泡，
/// 气泡的下边缘固定在 [VoiceRecordLayout.bubbleBottomMargin] 处
@immutable
class VoiceBubbleFrame {
  const VoiceBubbleFrame({
    required this.left,
    required this.width,
    required this.height,
    required this.tailX,
    required this.color,
    required this.waveColor,
    required this.waveWidth,
    required this.waveHeight,
    required this.waveCenterX,
    required this.waveCenterY,
    required this.waveAlpha,
    required this.textAlpha,
    required this.hintAlpha,
    required this.textBottomMargin,
  });

  final double left;
  final double width;

  /// 包含底部尖角的高度
  final double height;

  /// 尖角中心的 x 坐标
  final double tailX;
  final Color color;
  final Color waveColor;
  final double waveWidth;
  final double waveHeight;
  final double waveCenterX;
  final double waveCenterY;
  final double waveAlpha;
  final double textAlpha;
  final double hintAlpha;

  /// 文字下方为声波留出的距离
  final double textBottomMargin;

  static VoiceBubbleFrame lerp(
      VoiceBubbleFrame from, VoiceBubbleFrame to, double t) {
    double mix(double a, double b) => lerpDouble(a, b, t)!;
    return VoiceBubbleFrame(
      left: mix(from.left, to.left),
      width: mix(from.width, to.width),
      height: mix(from.height, to.height),
      tailX: mix(from.tailX, to.tailX),
      color: Color.lerp(from.color, to.color, t)!,
      waveColor: Color.lerp(from.waveColor, to.waveColor, t)!,
      waveWidth: mix(from.waveWidth, to.waveWidth),
      waveHeight: mix(from.waveHeight, to.waveHeight),
      waveCenterX: mix(from.waveCenterX, to.waveCenterX),
      waveCenterY: mix(from.waveCenterY, to.waveCenterY),
      waveAlpha: mix(from.waveAlpha, to.waveAlpha),
      textAlpha: mix(from.textAlpha, to.textAlpha),
      hintAlpha: mix(from.hintAlpha, to.hintAlpha),
      textBottomMargin: mix(from.textBottomMargin, to.textBottomMargin),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VoiceBubbleFrame &&
      other.left == left &&
      other.width == width &&
      other.height == height &&
      other.tailX == tailX &&
      other.color == color &&
      other.waveColor == waveColor &&
      other.waveWidth == waveWidth &&
      other.waveHeight == waveHeight &&
      other.waveCenterX == waveCenterX &&
      other.waveCenterY == waveCenterY &&
      other.waveAlpha == waveAlpha &&
      other.textAlpha == textAlpha &&
      other.hintAlpha == hintAlpha &&
      other.textBottomMargin == textBottomMargin;

  @override
  int get hashCode => Object.hash(
        left,
        width,
        height,
        tailX,
        color,
        waveColor,
        waveWidth,
        waveHeight,
        waveCenterX,
        waveCenterY,
        waveAlpha,
        textAlpha,
        hintAlpha,
        textBottomMargin,
      );
}
