import 'dart:convert';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/model/message_payload.dart';

MessageContentMeta restoreRequestNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_RESTORE_REQUEST,
    MessageFlag.TRANSPARENT,
    () => RestoreRequestNotificationContent());

class RestoreRequestNotificationContent extends NotificationMessageContent {
  int timestamp = 0;

  RestoreRequestNotificationContent() {
    timestamp = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    try {
      if (payload.binaryContent != null) {
        String jsonStr = utf8.decode(payload.binaryContent!);
        Map<String, dynamic> map = jsonDecode(jsonStr);
        timestamp = map['t'] ?? 0;
      }
    } catch (e) {
      print('RestoreRequestNotificationContent decode error: $e');
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    Map<String, dynamic> map = {
      't': timestamp,
    };
    payload.binaryContent = utf8.encode(jsonEncode(map));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    return 'Request restore from PC';
  }

  @override
  MessageContentMeta get meta => restoreRequestNotificationContentMeta;
}
