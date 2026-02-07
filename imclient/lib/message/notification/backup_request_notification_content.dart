import 'dart:convert';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/model/message_payload.dart';

MessageContentMeta backupRequestNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_BACKUP_REQUEST,
    MessageFlag.TRANSPARENT,
    () => BackupRequestNotificationContent());

class BackupRequestNotificationContent extends NotificationMessageContent {
  int conversationCount = 0;
  int messageCount = 0;
  bool includeMedia = false;
  int timestamp = 0;

  BackupRequestNotificationContent() {
    timestamp = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    try {
      if (payload.binaryContent != null) {
        String jsonStr = utf8.decode(payload.binaryContent!);
        Map<String, dynamic> map = jsonDecode(jsonStr);
        conversationCount = map['cc'] ?? 0;
        messageCount = map['mc'] ?? 0;
        includeMedia = map['m'] ?? false;
        timestamp = map['t'] ?? 0;
      }
    } catch (e) {
      print('BackupRequestNotificationContent decode error: $e');
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    Map<String, dynamic> map = {
      'cc': conversationCount,
      'mc': messageCount,
      'm': includeMedia,
      't': timestamp,
    };
    payload.binaryContent = utf8.encode(jsonEncode(map));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    return 'Request backup to PC';
  }

  @override
  MessageContentMeta get meta => backupRequestNotificationContentMeta;
}
