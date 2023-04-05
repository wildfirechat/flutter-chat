import 'dart:convert';
import 'dart:typed_data';

import '../../model/message_payload.dart';
import '../message.dart';
import '../message_content.dart';


// ignore: non_constant_identifier_names
MessageContent DeleteMessageContentCreator() {
  return DeleteMessageContent();
}

const deleteMessageContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_DELETE,
    MessageFlag.NOT_PERSIST, DeleteMessageContentCreator);

class DeleteMessageContent extends MessageContent {
  late String operatorId;
  late int messageUid;

  @override
  Future<void> decode(MessagePayload payload) async {
    super.decode(payload);
    if(payload.content != null) {
      operatorId = payload.content!;
    } else {
      operatorId = "";
    }
    if(payload.binaryContent != null) {
      messageUid = int.parse(utf8.decode(payload.binaryContent!));
    } else {
      messageUid = 0;
    }
  }

  @override
  MessageContentMeta get meta => deleteMessageContentMeta;

  @override
  Future<String> formatNotification(Message message) async {
    return "";
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = operatorId;
    payload.binaryContent = Uint8List.fromList(utf8.encode(messageUid.toString()));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return "";
  }
}
