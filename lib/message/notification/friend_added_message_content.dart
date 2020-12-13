import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/message/notification/notification_message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/message/message.dart';

// ignore: non_constant_identifier_names
MessageContent FriendAddedMessageContentCreator() {
  return new FriendAddedMessageContent();
}

const friendAddedContentMeta = MessageContentMeta(MESSAGE_FRIEND_ADDED_NOTIFICATION,
    MessageFlag.PERSIST, FriendAddedMessageContentCreator);

class FriendAddedMessageContent extends NotificationMessageContent {
  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    return payload;
  }


  @override
  Future<String> formatNotification(Message message) async {
    return digest(message);
  }

  @override
  Future<String> digest(Message message) async {
    return "你们已经是好友了，可以开始聊天了。";
  }

  @override
  MessageContentMeta get meta => friendAddedContentMeta;

}
