import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent StreamingTextGeneratedMessageContentCreator() {
  return StreamingTextGeneratedMessageContent();
}

const streamingTextGeneratedContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_STREAMING_TEXT_GENERATED,
    MessageFlag.PERSIST_AND_COUNT,
    StreamingTextGeneratedMessageContentCreator);

class StreamingTextGeneratedMessageContent extends MessageContent {
  StreamingTextGeneratedMessageContent({this.text = "", this.streamId = ""});

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
  MessageContentMeta get meta => streamingTextGeneratedContentMeta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamingTextGeneratedMessageContent &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          streamId == other.streamId;

  @override
  int get hashCode => text.hashCode ^ streamId.hashCode;
}
