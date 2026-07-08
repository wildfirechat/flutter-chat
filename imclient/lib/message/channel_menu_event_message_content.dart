import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent ChannelMenuEventContentCreator() {
  return ChannelMenuEventMessageContent();
}

const channelMenuEventContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_CHANNEL_MENU_EVENT,
  MessageFlag.PERSIST,
  ChannelMenuEventContentCreator,
);

/// 频道菜单事件消息
///
/// 用户在频道中点击自定义菜单时产生的事件
/// 消息类型: 73
class ChannelMenuEventMessageContent extends MessageContent {
  /// 频道ID
  late String channelId;

  /// 菜单键值
  String key = '';

  /// 事件值
  String value = '';

  @override
  MessageContentMeta get meta => channelMenuEventContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    channelId = payload.searchableContent ?? '';

    if (payload.content != null) {
      key = payload.content!;
    }
    value = payload.pushContent ?? '';
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = channelId;
    payload.content = key;
    payload.pushContent = value;
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[频道菜单事件]';
  }
}
