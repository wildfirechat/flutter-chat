import 'dart:convert';

import '../../model/message_payload.dart';
import '../message.dart';
import '../message_content.dart';
import 'notification_message_content.dart';


// ignore: non_constant_identifier_names
MessageContent DeleteMessageContentCreator() {
  return new DeleteMessageContent();
}

const deleteMessageContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_DELETE,
    MessageFlag.NOT_PERSIST, DeleteMessageContentCreator);

class DeleteMessageContent extends NotificationMessageContent {
  String operatorId;
  int messageUid;

  @override
  Future<void> decode(MessagePayload payload) async {
    super.decode(payload);
    operatorId = payload.content;
    messageUid = int.parse(utf8.decode(payload.binaryContent));
  }

  @override
  MessageContentMeta get meta => deleteMessageContentMeta;

  @override
  Future<String> formatNotification(Message message) async {
    return null;
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    payload.content = operatorId;
    payload.binaryContent = utf8.encode(messageUid.toString());
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return null;
  }
}
