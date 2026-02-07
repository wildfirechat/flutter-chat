import 'dart:convert';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/model/message_payload.dart';

MessageContentMeta restoreResponseNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_RESTORE_RESPONSE,
    MessageFlag.TRANSPARENT,
    () => RestoreResponseNotificationContent());

class RestoreResponseNotificationContent extends NotificationMessageContent {
  bool approved = false;
  String? serverIP;
  int serverPort = 0;

  RestoreResponseNotificationContent();

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    try {
      if (payload.binaryContent != null) {
        String jsonStr = utf8.decode(payload.binaryContent!);
        Map<String, dynamic> map = jsonDecode(jsonStr);
        approved = map['a'] ?? false;
        if (approved) {
          serverIP = map['ip'];
          serverPort = map['p'] ?? 0;
        }
      }
    } catch (e) {
      print('RestoreResponseNotificationContent decode error: $e');
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    Map<String, dynamic> map = {
      'a': approved,
    };
    if (approved) {
      if (serverIP != null) {
        map['ip'] = serverIP;
      }
      map['p'] = serverPort;
    }
    payload.binaryContent = utf8.encode(jsonEncode(map));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    return approved ? 'Approved restore request' : 'Rejected restore request';
  }

  @override
  MessageContentMeta get meta => restoreResponseNotificationContentMeta;
}
