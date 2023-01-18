
// ignore: non_constant_identifier_names
import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

MessageContent TypingMessageContentCreator() {
  return new TypingMessageContent();
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
  TypingType type;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    type = TypingType.values[int.parse(payload.content)];
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    payload.content = type.index.toString();
    return payload;
  }


  @override
  Future<String> digest(Message message) async {
    return null;
  }

  @override
  MessageContentMeta get meta => typingContentMeta;
}
