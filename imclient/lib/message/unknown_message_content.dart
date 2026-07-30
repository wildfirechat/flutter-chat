import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

MessageContent UnknownContentCreator() {
  return UnknownMessageContent();
}

const unknownContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_TEXT,
    MessageFlag.PERSIST_AND_COUNT, UnknownContentCreator);

class UnknownMessageContent extends MessageContent {
  late MessagePayload rawPayload;
  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    rawPayload = payload;
  }

  @override
  MessagePayload encode() {
    return rawPayload;
  }

  @override
  Future<String> digest(Message message) async {
    return '未知消息';
  }

  @override
  MessageContentMeta get meta => unknownContentMeta;
}
