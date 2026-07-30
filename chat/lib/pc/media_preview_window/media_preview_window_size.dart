import 'dart:math' as math;
import 'dart:ui';

import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';

/// PC 媒体预览窗口的尺寸策略:窗口形状跟着**当前预览的那条媒体**走
/// (参考微信),而不是一直停在开窗时那条媒体的大小上。
///
/// 尺寸来源:
/// - 图片直接取消息里的原始宽高([ImageMessageContent.width]/[ImageMessageContent.height],
///   发送端已写进 payload),不在这里解码图片;
/// - 视频消息本身不带宽高(野火各端的 VideoMessageContent 只有时长和缩略图),
///   [mediaSize] 返回 null,由预览窗口在播放器初始化后拿真实尺寸再调一次,
///   见 MediaPreviewWindowApp。
class MediaPreviewWindowSize {
  MediaPreviewWindowSize._();

  /// 媒体尺寸未知时的窗口大小(视频还没加载出来、图片消息没写宽高等)。
  static const Size fallback = Size(960, 640);

  /// 窗口尺寸下限:比这更小的媒体不再缩窗口,居中留黑边即可。
  static const Size minSize = Size(720, 480);

  /// 窗口尺寸上限;同时还要受 [_screenRatio] 约束。
  static const Size maxSize = Size(1280, 820);

  /// 窗口最多占屏幕的比例(1366x768 这类小屏上 [maxSize] 会超出可视区域)。
  static const double _screenRatio = 0.85;

  /// 预览 [message] 时窗口应有的大小。
  static Size forMessage(Message? message) => forMedia(mediaSize(message));

  /// 消息自带的媒体像素尺寸;视频消息不带宽高,返回 null。
  static Size? mediaSize(Message? message) {
    final content = message?.content;
    if (content is ImageMessageContent) {
      final double w = content.width.toDouble();
      final double h = content.height.toDouble();
      if (w > 0 && h > 0) return Size(w, h);
    }
    return null;
  }

  /// 按媒体像素尺寸算窗口大小:超出上限时等比缩进去,再抬到下限之上。
  static Size forMedia(Size? media) {
    final Size limit = _limit();
    final Size floor = Size(
      math.min(minSize.width, limit.width),
      math.min(minSize.height, limit.height),
    );
    if (media == null || media.width <= 0 || media.height <= 0) {
      return Size(
        fallback.width.clamp(floor.width, limit.width),
        fallback.height.clamp(floor.height, limit.height),
      );
    }
    double w = media.width;
    double h = media.height;
    final double scale = math.min(limit.width / w, limit.height / h);
    if (scale < 1) {
      w *= scale;
      h *= scale;
    }
    return Size(math.max(w, floor.width), math.max(h, floor.height));
  }

  /// 屏幕约束后的尺寸上限。取当前引擎所在窗口的显示器(主窗口/子窗口各自的
  /// isolate 里 views.first 就是自己那个窗口),拿不到时退回 [maxSize]。
  static Size _limit() {
    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) return maxSize;
    final Display display = views.first.display;
    final double dpr = display.devicePixelRatio;
    if (dpr <= 0 || display.size.isEmpty) return maxSize;
    final Size logical = display.size / dpr;
    return Size(
      math.min(maxSize.width, logical.width * _screenRatio),
      math.min(maxSize.height, logical.height * _screenRatio),
    );
  }
}
