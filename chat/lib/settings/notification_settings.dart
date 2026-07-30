import 'package:imclient/imclient.dart';

/// 通知/消息设置的跨端共享业务语义，移动端
/// [MessageNotificationSettings] 与 PC 端设置页共用，保证两端行为一致：
///
/// - 布尔型 user setting 的取反语义：服务端存的是"是否静默/隐藏/禁用"，
///   UI 呈现为正向开关（"接收通知/显示详情/同步草稿"），读写都要取反。
/// - 免打扰时段：服务端按 UTC 分钟存储，默认时段为本地 21:00 - 次日 07:00。
class NotificationSettings {
  NotificationSettings._();

  /// 服务端免打扰时间以 UTC 分钟数存储，当前客户端固定按东八区呈现
  /// （与 iOS/Android 官方客户端一致）。若要支持其他时区，
  /// 统一改这里：DateTime.now().timeZoneOffset.inMinutes。
  static const int utcOffsetMinutes = 8 * 60;

  /// 默认免打扰时段：本地 21:00 - 次日 07:00（换算为 UTC 分钟）。
  static const int defaultNoDisturbStart = 21 * 60 - utcOffsetMinutes;
  static const int defaultNoDisturbEnd = 7 * 60 - utcOffsetMinutes;

  /// 读取布尔设置。[invert] 为 true 时存储语义与 UI 相反
  /// （如 kUserSettingGlobalSilent 存"静默"，UI 显示"接收通知"）。
  static Future<bool> getBool(int scope, {bool invert = false}) async {
    final value = await Imclient.getUserSetting(scope, "");
    final enabled = !(value.isEmpty || value == '0');
    return invert ? !enabled : enabled;
  }

  /// 写入布尔设置，[value] 为 UI 上的开关值，[invert] 同 [getBool]。
  /// 失败时调用方应回读并提示。
  static void setBool(
    int scope,
    bool value, {
    bool invert = false,
    required void Function() onSuccess,
    required void Function(int errorCode) onFailure,
  }) {
    final sendVal = invert ? !value : value;
    Imclient.setUserSetting(
        scope, "", sendVal ? "1" : "0", onSuccess, onFailure);
  }

  /// 格式化免打扰时段（UTC 分钟）为本地时间 'HH:mm - HH:mm'。
  static String formatNoDisturbTime(int startTime, int endTime) {
    final localStart = startTime + utcOffsetMinutes;
    final localEnd = endTime + utcOffsetMinutes;

    final startHour = localStart ~/ 60;
    final startMin = localStart % 60;
    final endHour = localEnd ~/ 60;
    final endMin = localEnd % 60;

    return '${startHour.toString().padLeft(2, '0')}:${startMin.toString().padLeft(2, '0')}'
        ' - '
        '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
  }
}
