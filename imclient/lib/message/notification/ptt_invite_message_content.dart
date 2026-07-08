import '../../model/message_payload.dart';
import '../message.dart';
import '../message_content.dart';
import 'notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent PttInviteContentCreator() {
  return PttInviteMessageContent();
}

const pttInviteContentMeta = MessageContentMeta(
  VOIP_CONTENT_PTT_INVITE,
  MessageFlag.PERSIST,
  PttInviteContentCreator,
);

/// PTT对讲邀请消息内容
///
/// 邀请用户加入对讲频道
/// 消息类型: 420
class PttInviteMessageContent extends NotificationMessageContent {
  /// 对讲频道ID
  String channelId = '';

  /// 频道名称
  String channelName = '';

  /// 邀请者ID
  String inviterId = '';

  @override
  MessageContentMeta get meta => pttInviteContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    channelId = payload.searchableContent ?? '';
    channelName = payload.pushContent ?? '';
    inviterId = payload.content ?? '';
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = channelId;
    payload.pushContent = channelName;
    payload.content = inviterId;
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  Future<String> formatNotification(Message message) async {
    return '[对讲邀请]${channelName.isNotEmpty ? ' $channelName' : ''}';
  }
}
