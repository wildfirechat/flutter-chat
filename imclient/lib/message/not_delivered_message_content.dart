import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent NotDeliveredMessageContentCreator() {
  return NotDeliveredMessageContent();
}

const notDeliveredContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_NOT_DELIVERED,
  MessageFlag.PERSIST,
  NotDeliveredMessageContentCreator,
);

/// 消息未能送达消息
///
/// 当消息因为某些原因未送达时，服务器会下发此消息
/// 消息类型: 16
class NotDeliveredMessageContent extends MessageContent {
  /// 原消息ID
  int originalMessageUid = 0;

  /// 未送达原因
  String reason = '';

  @override
  MessageContentMeta get meta => notDeliveredContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    reason = payload.content ?? '';
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = reason;
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[消息未送达]';
  }
}
