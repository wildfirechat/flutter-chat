import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/notification/recall_notificiation_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:imclient/model/pc_online_info.dart';

class WfcNotificationManager {
  static final WfcNotificationManager _instance = WfcNotificationManager._internal();
  factory WfcNotificationManager() => _instance;
  WfcNotificationManager._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String wfcNotificationChannelId = "wfc_notification";

  final List<int> _notificationMessages = [];
  int _friendRequestNotificationId = 10000;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
            onDidReceiveLocalNotification: onDidReceiveLocalNotification);

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);

    _createNotificationChannel();
  }

  Future<void> _createNotificationChannel() async {
    if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          wfcNotificationChannelId,
          '野火IM 消息通知',
          description: 'WildfireChat Message Notification',
          importance: Importance.high,
          playSound: true,
          // sound: RawResourceAndroidNotificationSound('receive_msg_notification'),
          enableLights: true,
          enableVibration: true,
          showBadge: true,
        );

        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
    }
  }

  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
  }

  void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      debugPrint("Notification tapped with payload: $payload");
      // TODO: Navigate to conversation
    }
  }

  Future<void> handleReceiveMessage(List<Message> messages) async {
    if (messages.isEmpty) return;

    if (await Imclient.isNoDisturbing()) return;
    if (await Imclient.isGlobalSilent()) return;

    if (await Imclient.isMuteNotificationWhenPcOnline()) {
      List<PCOnlineInfo> onlineInfos = await Imclient.getOnlineInfos();
      for (var info in onlineInfos) {
        if (info.isOnline) return;
      }
    }

    bool hiddenNotificationDetail = await Imclient.isHiddenNotificationDetail();

    for (var message in messages) {
      if (message.direction == MessageDirection.MessageDirection_Send) continue;

      if (message.content.meta.flag != MessageFlag.PERSIST_AND_COUNT &&
          message.content is! RecallNotificationContent) {
        continue;
      }

      var conversationInfo = await Imclient.getConversationInfo(message.conversation);
      if (conversationInfo.isSilent) continue;

      String pushContent = hiddenNotificationDetail ? "新消息" : "";
      if (pushContent.isEmpty) {
        pushContent = await message.content.digest(message);
      }

      int unreadCount = (await Imclient.getConversationUnreadCount(message.conversation)).unread;
      if (unreadCount > 1) {
        pushContent = "[$unreadCount条]$pushContent";
      }

      String title = "";
      if (message.conversation.conversationType == ConversationType.Single) {
        UserInfo? userInfo = await Imclient.getUserInfo(message.conversation.target);
        title = userInfo?.displayName ?? "新消息";
      } else if (message.conversation.conversationType == ConversationType.Group) {
        GroupInfo? groupInfo = await Imclient.getGroupInfo(message.conversation.target);
        title = groupInfo?.name ?? "群聊";
        if (groupInfo != null && groupInfo.remark != null && groupInfo.remark!.isNotEmpty) {
            title = groupInfo.remark!;
        }
      } else if (message.conversation.conversationType == ConversationType.Channel) {
        ChannelInfo? channelInfo = await Imclient.getChannelInfo(message.conversation.target);
        title = channelInfo?.name ?? "公众号新消息";
      } else {
        title = "新消息";
      }

      int id = _notificationId(message.messageUid ?? 0);
      showNotification(id, title, pushContent, message.conversation.target);
    }
  }

  Future<void> handleFriendRequest(List<String> friendRequests) async {
      if (friendRequests.isEmpty) return;
      if (await Imclient.isGlobalSilent()) return;

      UserInfo? userInfo = await Imclient.getUserInfo(friendRequests[0], refresh: true);
      if (userInfo != null) {
          String text = userInfo.displayName ?? "";
          if (friendRequests.length > 1) {
              text += " 等";
          }
          text += "请求添加你为好友";
          String title = "好友申请";

          _friendRequestNotificationId++;
          showNotification(_friendRequestNotificationId, title, text, "friend_request");
      }
  }

  Future<void> showNotification(int id, String title, String body, String payload) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
            wfcNotificationChannelId,
            '野火IM 消息通知',
            channelDescription: 'WildfireChat Message Notification',
            importance: Importance.high,
            priority: Priority.high,
            ticker: 'ticker',
            // sound: RawResourceAndroidNotificationSound('receive_msg_notification'),
        );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
        id, title, body, notificationDetails,
        payload: payload);
  }

  int _notificationId(int messageUid) {
      if (!_notificationMessages.contains(messageUid)) {
          _notificationMessages.add(messageUid);
      }
      return _notificationMessages.indexOf(messageUid);
  }

  void clearAllNotification() {
      flutterLocalNotificationsPlugin.cancelAll();
      _notificationMessages.clear();
  }
}
