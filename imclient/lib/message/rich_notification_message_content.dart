import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';
import 'notification/notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent RichNotificationContentCreator() {
  return RichNotificationMessageContent();
}

const richNotificationContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_RICH_NOTIFICATION,
  MessageFlag.PERSIST,
  RichNotificationContentCreator,
);

/// 富通知消息内容
///
/// 富文本类型的系统通知消息，可包含标题、描述、图片等。
/// 消息类型: 12
class RichNotificationMessageContent extends NotificationMessageContent {
  /// 通知标题
  String title = '';

  /// 通知描述
  String desc = '';

  /// 通知图片地址
  String imageUrl = '';

  /// 点击通知后的跳转链接
  String redirectUrl = '';

  /// 通知来源
  String sourceId = '';

  @override
  MessageContentMeta get meta => richNotificationContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    title = payload.searchableContent ?? '';

    if (payload.binaryContent != null) {
      try {
        Map<dynamic, dynamic> json =
            jsonDecode(utf8.decode(payload.binaryContent!));
        desc = json['d'] ?? '';
        imageUrl = json['i'] ?? '';
        redirectUrl = json['u'] ?? '';
        sourceId = json['s'] ?? '';
      } catch (e) {
        title = payload.searchableContent ?? '';
      }
    }

    if (payload.pushContent != null) {
      title = payload.pushContent!;
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = title;
    payload.pushContent = title;

    Map<String, dynamic> jsonObject = {
      'd': desc,
      'i': imageUrl,
      'u': redirectUrl,
      's': sourceId,
    };
    payload.binaryContent =
        Uint8List.fromList(utf8.encode(jsonEncode(jsonObject)));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return title.isNotEmpty ? title : '[富通知]';
  }

  @override
  Future<String> formatNotification(Message message) async {
    return title.isNotEmpty ? title : desc;
  }
}
