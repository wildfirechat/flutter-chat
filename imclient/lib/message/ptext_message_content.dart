import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent PTextMessageContentCreator() {
  return PTextMessageContent();
}

const ptextContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_P_TEXT,
    MessageFlag.PERSIST, PTextMessageContentCreator);

class PTextMessageContent extends MessageContent {
  PTextMessageContent();
  late String text;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.searchableContent != null) {
      text = payload.searchableContent!;
    } else {
      text = "";
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
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
