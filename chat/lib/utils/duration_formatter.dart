/// 媒体时长格式化。
///
/// 协议里 [VideoMessageContent.duration] 的单位是**毫秒**,直接拼 `${duration}s`
/// 会把 18 秒的视频显示成 "18000s",所以统一走这里换算并格式化。
library;

/// 把毫秒时长格式化成 `mm:ss`(超过一小时为 `h:mm:ss`)。
///
/// 负值与非法值按 0 处理。
String formatMediaDuration(int milliseconds) {
  final int totalSeconds = milliseconds <= 0 ? 0 : milliseconds ~/ 1000;
  String two(int n) => n.toString().padLeft(2, '0');
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${two(minutes)}:${two(seconds)}';
  }
  return '${two(minutes)}:${two(seconds)}';
}
