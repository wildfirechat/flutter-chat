import 'dart:convert';

import '../model/channel_info.dart';
import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent ChannelMenuEventContentCreator() {
  return ChannelMenuEventMessageContent();
}

/// 与 Android/iOS 一致:透传消息,客户端不在线会丢弃,不存储不计数。
/// 菜单点击只是通知频道后台,不该在会话里留下记录。
const channelMenuEventContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_CHANNEL_MENU_EVENT,
  MessageFlag.TRANSPARENT,
  ChannelMenuEventContentCreator,
);

/// 频道菜单事件消息
///
/// 用户点击频道自定义菜单(type 为 click 的菜单项)时发给频道后台的事件,
/// 菜单本身以 json 放在 payload.content 里。
/// 消息类型: 73
class ChannelMenuEventMessageContent extends MessageContent {
  ChannelMenuEventMessageContent([this.menu]);

  /// 被点击的菜单项
  ChannelMenu? menu;

  @override
  MessageContentMeta get meta => channelMenuEventContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload.content == null || payload.content!.isEmpty) {
      return;
    }
    try {
      menu = ChannelMenu.fromJson(jsonDecode(payload.content!));
    } catch (e) {
      menu = null;
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = menu == null ? '' : jsonEncode(menu!.toJson());
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '';
  }
}
