import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';

class WfcNotificationManager {
  static final WfcNotificationManager _instance = WfcNotificationManager._internal();
  factory WfcNotificationManager() => _instance;
  WfcNotificationManager._internal();

  Future<void> init() async {}

  Future<void> handleReceiveMessage(List<Message> messages) async {}

  Future<void> handleFriendRequest(List<String> newUserRequests) async {}

  Future<void> cancelNotification(int notificationId) async {}

  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {}

  void onDidReceiveNotificationResponse(dynamic notificationResponse) async {}
}
