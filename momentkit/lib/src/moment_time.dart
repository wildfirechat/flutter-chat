/// 朋友圈时间格式化（微信风格）。
class MomentTime {
  MomentTime._();

  /// [serverTime] 兼容秒/毫秒两种单位（服务端协议为秒，本地消息为毫秒）。
  static DateTime toDateTime(int serverTime) {
    final millis = serverTime > 100000000000 ? serverTime : serverTime * 1000;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static String format(int serverTime) {
    if (serverTime <= 0) return '';
    final dt = toDateTime(serverTime);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1 && dt.day == now.day) return '刚刚';
    if (diff.inMinutes < 60 && dt.day == now.day) return '${diff.inMinutes}分钟前';
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${diff.inHours}小时前';
    }
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return '昨天';
    }
    if (diff.inDays < 7 && dt.isAfter(DateTime(now.year, now.month, now.day - 7))) {
      return '${diff.inDays}天前';
    }
    if (dt.year == now.year) {
      return '${dt.month}月${dt.day}日';
    }
    return '${dt.year}年${dt.month}月${dt.day}日';
  }

  static String formatMessageTime(int serverTime) {
    if (serverTime <= 0) return '';
    final dt = toDateTime(serverTime);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(dt.year, dt.month, dt.day);
    final hm = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (thatDay == today) return hm;
    if (thatDay == today.subtract(const Duration(days: 1))) return '昨天 $hm';
    if (dt.year == now.year) return '${dt.month}月${dt.day}日 $hm';
    return '${dt.year}年${dt.month}月${dt.day}日 $hm';
  }
}
