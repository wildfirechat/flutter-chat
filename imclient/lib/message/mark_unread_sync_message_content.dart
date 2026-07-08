import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent MarkUnreadSyncMessageContentCreator() {
  return MarkUnreadSyncMessageContent();
}

const markUnreadSyncContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_MARK_UNREAD_SYNC,
  MessageFlag.TRANSPARENT,
  MarkUnreadSyncMessageContentCreator,
);

/// 同步标记未读消息
///
/// 用于多端同步"标记未读"状态，透传消息不存储不计数
/// 消息类型: 31
class MarkUnreadSyncMessageContent extends MessageContent {
  @override
  MessageContentMeta get meta => markUnreadSyncContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[标记未读]';
  }
}
