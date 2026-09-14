import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 按住说话浮层的配色，参考微信深色模式，移植自 android-chat
///
/// 浮层本身按深色设计，明暗主题下都一样（同通话界面），所以不走 AppColors；
/// 只有气泡跟随 app 主色调，见 [VoiceBubbleColors]
abstract final class VoiceRecordPalette {
  // 整屏遮罩和操作区的深灰背景
  static const Color dim = Color(0xCC111111);
  static const Color panel = Color(0xFF444444);

  // 底部弧形区域和两条弧形按钮
  static const Color arc = Color(0xFF575757);
  static const Color arcSelectedTop = Color(0xFF636363);
  static const Color arcSelectedBottom = Color(0xFF808080);
  static const Color arcRim = Color(0xFF767676);
  static const Color arcLabel = Color(0xFFDDDDDD);
  static const Color pill = Color(0xFF575757);
  static const Color pillSelected = Color(0xFF9A9A9A);
  static const Color pillLabel = Color(0xFFE6E6E6);
  static const Color selectedLabel = Color(0xFF111111);
  static const Color pillHint = Color(0xFFD0D0D0);

  static const Color countDown = Color(0xCCFFFFFF);

  // 编辑文字时底部的按钮
  static const Color circleButton = Color(0xFF575757);
  static const Color circleButtonPressed = Color(0xFF6A6A6A);
  static const Color circleButtonIcon = Color(0xFFFFFFFF);
  static const Color actionLabel = Color(0xFFBDBDBD);
  static const Color sendButton = Color(0xFFDADADA);
  static const Color sendButtonPressed = Color(0xFFBDBDBD);
  static const Color sendButtonDisabled = Color(0xFF4E4E4E);
  static const Color sendButtonText = Color(0xFF111111);
  static const Color sendButtonTextDisabled = Color(0xFF737373);

  // 气泡上的文字和声波
  static const Color darkContent = Color(0xFF191919);
  static const Color lightContent = Color(0xFFFFFFFF);
}

/// 浮层的字号，移植自 android-chat（sp）
///
/// 弧形按钮上的文字沿圆弧逐字排版、放不下时缩小，和气泡、按钮的尺寸一起构成这块图形，
/// 所以不走 AppText 的字号阶梯
abstract final class VoiceRecordTextSize {
  static const double arcLabel = 18;
  static const double pillLabel = 17;
  static const double pillHint = 14;
  static const double countDown = 14;
  static const double bubbleText = 22;
  static const double bubbleHint = 18;
  static const double actionLabel = 15;
  static const double sendButton = 19;
}

/// 气泡配色：平时用 app 主色调，文字和声波根据主色调的深浅用深色或白色；取消、出错时用红底白字
@immutable
class VoiceBubbleColors {
  VoiceBubbleColors({required this.normal, required this.alert})
      : content = normal.computeLuminance() > 0.3
            ? VoiceRecordPalette.darkContent
            : VoiceRecordPalette.lightContent;

  final Color normal;

  /// [normal] 上的文字和声波
  final Color content;
  final Color alert;

  /// [alert] 上的文字和声波
  Color get alertContent => VoiceRecordPalette.lightContent;

  @override
  bool operator ==(Object other) =>
      other is VoiceBubbleColors &&
      other.normal == normal &&
      other.alert == alert;

  @override
  int get hashCode => Object.hash(normal, alert);
}
