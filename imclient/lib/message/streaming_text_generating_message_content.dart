import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent StreamingTextGeneratingMessageContentCreator() {
  return StreamingTextGeneratingMessageContent();
}

const streamingTextGeneratingContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_STREAMING_TEXT_GENERATING,
    MessageFlag.TRANSPARENT,
    StreamingTextGeneratingMessageContentCreator);

class StreamingTextGeneratingMessageContent extends MessageContent {
  StreamingTextGeneratingMessageContent({this.text = "", this.streamId = ""});
  
  String text;
  String streamId;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload.searchableContent != null) {
      text = payload.searchableContent!;
    } else {
      text = "";
    }
    if (payload.content != null) {
      streamId = payload.content!;
    } else {
      streamId = "";
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = text;
    payload.content = streamId;
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return text;
  }

  @override
  MessageContentMeta get meta => streamingTextGeneratingContentMeta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamingTextGeneratingMessageContent &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          streamId == other.streamId;

  @override
  int get hashCode => text.hashCode ^ streamId.hashCode;
}
