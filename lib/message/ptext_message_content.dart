import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/message/message.dart';

// ignore: non_constant_identifier_names
MessageContent PTextMessageContentCreator() {
  return new PTextMessageContent();
}

const ptextContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_P_TEXT,
    MessageFlag.PERSIST, PTextMessageContentCreator);

class PTextMessageContent extends MessageContent {
  PTextMessageContent({String text}) : this.text = text;
  String text;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    text = payload.searchableContent;
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    payload.searchableContent = text;
    return payload;
  }


  @override
  Future<String> digest(Message message) async {
    return text;
  }

  @override
  MessageContentMeta get meta => ptextContentMeta;
}
