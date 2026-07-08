import '../../model/message_payload.dart';
import '../message.dart';
import '../message_content.dart';
import 'notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent JoinCallRequestContentCreator() {
  return JoinCallRequestMessageContent();
}

const joinCallRequestContentMeta = MessageContentMeta(
  VOIP_CONTENT_JOIN_CALL_REQUEST,
  MessageFlag.PERSIST,
  JoinCallRequestContentCreator,
);

/// 加入通话请求消息内容
///
/// 请求加入已进行的多人通话
/// 消息类型: 417
class JoinCallRequestMessageContent extends NotificationMessageContent {
  /// 通话ID
  String callId = '';

  /// 请求者ID
  String requesterId = '';

  @override
  MessageContentMeta get meta => joinCallRequestContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    callId = payload.searchableContent ?? '';
    requesterId = payload.content ?? '';
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = callId;
    payload.content = requesterId;
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  Future<String> formatNotification(Message message) async {
    return '请求加入通话';
  }
}
