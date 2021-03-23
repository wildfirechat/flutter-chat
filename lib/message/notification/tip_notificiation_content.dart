import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/message/notification/notification_message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';

// ignore: non_constant_identifier_names
MessageContent TipNotificationContentCreator() {
  return new TipNotificationContent();
}

const tipNotificationContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_TIP,
    MessageFlag.PERSIST, TipNotificationContentCreator);

class TipNotificationContent extends NotificationMessageContent {
  String tip;

  @override
  Future<void> decode(MessagePayload payload) async {
    super.decode(payload);
    tip = payload.content;
  }

  @override
  MessageContentMeta get meta => tipNotificationContentMeta;

  @override
  Future<String> formatNotification(Message message) async {
    return tip;
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    payload.content = tip;
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return tip;
  }
}
