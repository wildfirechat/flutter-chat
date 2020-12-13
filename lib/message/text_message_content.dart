import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/message/message.dart';

// ignore: non_constant_identifier_names
MessageContent TextMessageContentCreator() {
  return new TextMessageContent();
}

const textContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_TEXT,
    MessageFlag.PERSIST_AND_COUNT, TextMessageContentCreator);

class TextMessageContent extends MessageContent {
  TextMessageContent({String text}) : this.text = text;
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
  MessageContentMeta get meta => textContentMeta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextMessageContent &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;
}
