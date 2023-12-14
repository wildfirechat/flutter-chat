
// ignore: non_constant_identifier_names
import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

MessageContent TypingMessageContentCreator() {
  return TypingMessageContent();
}

const typingContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_TYPING,
    MessageFlag.TRANSPARENT, TypingMessageContentCreator);

enum TypingType {
  Typing_TEXT,
  Typing_VOICE,
  Typing_CAMERA,
  Typing_LOCATION,
  Typing_FILE,
}

class TypingMessageContent extends MessageContent {
  late TypingType type;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.content != null) {
      type = TypingType.values[int.parse(payload.content!)];
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = type.index.toString();
    return payload;
  }


  @override
  Future<String> digest(Message message) async {
    return "";
  }

  @override
  MessageContentMeta get meta => typingContentMeta;
}
