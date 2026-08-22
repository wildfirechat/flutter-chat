import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent StreamingTextCancelledMessageContentCreator() {
  return StreamingTextCancelledMessageContent();
}

/// 流式文本取消消息（20）：生成无产出/失败时由机器人发送，携带 streamId。
/// 客户端按 streamId 将正在显示的 generating(14)/generated(15) 消息从界面删除；
/// Transparent 透传，不落库、不计数，取消消息自身不进入消息列表。
const streamingTextCancelledContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_STREAMING_TEXT_CANCELLED,
    MessageFlag.TRANSPARENT,
    StreamingTextCancelledMessageContentCreator);

class StreamingTextCancelledMessageContent extends MessageContent {
  StreamingTextCancelledMessageContent({this.text = "", this.streamId = ""});

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
  MessageContentMeta get meta => streamingTextCancelledContentMeta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamingTextCancelledMessageContent &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          streamId == other.streamId;

  @override
  int get hashCode => text.hashCode ^ streamId.hashCode;
}
