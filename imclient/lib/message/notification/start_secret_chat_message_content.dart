import '../../model/message_payload.dart';
import '../message.dart';
import '../message_content.dart';
import 'notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent StartSecretChatContentCreator() {
  return StartSecretChatMessageContent();
}

const startSecretChatContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_CREATE_SECRET_CHAT,
  MessageFlag.PERSIST,
  StartSecretChatContentCreator,
);

/// 发起密聊通知消息
///
/// 发起端到端加密的密聊请求
/// 消息类型: 40
class StartSecretChatMessageContent extends NotificationMessageContent {
  /// 密聊ID
  String secretChatId = '';

  /// 发起者ID
  String fromUserId = '';

  /// 目标用户ID
  String targetUserId = '';

  @override
  MessageContentMeta get meta => startSecretChatContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    secretChatId = payload.searchableContent ?? '';
    fromUserId = payload.content ?? '';
    targetUserId = payload.pushContent ?? '';
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = secretChatId;
    payload.content = fromUserId;
    payload.pushContent = targetUserId;
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  Future<String> formatNotification(Message message) async {
    return '发起密聊';
  }
}
