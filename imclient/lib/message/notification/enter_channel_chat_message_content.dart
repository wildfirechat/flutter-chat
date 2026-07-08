import 'dart:convert';
import 'dart:typed_data';

import '../../model/message_payload.dart';
import '../message.dart';
import '../message_content.dart';
import 'notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent EnterChannelChatContentCreator() {
  return EnterChannelChatMessageContent();
}

const enterChannelChatContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_ENTER_CHANNEL_CHAT,
  MessageFlag.PERSIST,
  EnterChannelChatContentCreator,
);

/// 进入频道聊天通知消息
///
/// 用户进入频道时发送的通知消息
/// 消息类型: 71
class EnterChannelChatMessageContent extends NotificationMessageContent {
  /// 频道ID
  late String channelId;

  /// 频道名称
  String channelName = '';

  @override
  MessageContentMeta get meta => enterChannelChatContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    channelId = payload.searchableContent ?? '';

    if (payload.binaryContent != null) {
      try {
        Map<dynamic, dynamic> json =
            jsonDecode(utf8.decode(payload.binaryContent!));
        channelName = json['n'] ?? '';
      } catch (e) {
        channelId = '';
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = channelId;

    Map<String, dynamic> jsonObject = {'n': channelName};
    payload.binaryContent =
        Uint8List.fromList(utf8.encode(jsonEncode(jsonObject)));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  Future<String> formatNotification(Message message) async {
    return '进入频道 ${channelName.isNotEmpty ? channelName : channelId}';
  }
}
