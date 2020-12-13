import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/message/notification/notification_message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/message/message.dart';

// ignore: non_constant_identifier_names
MessageContent FriendGreetingMessageContentCreator() {
  return new FriendGreetingMessageContent();
}

const friendGreetingContentMeta = MessageContentMeta(MESSAGE_FRIEND_GREETING,
    MessageFlag.PERSIST, FriendGreetingMessageContentCreator);

class FriendGreetingMessageContent extends NotificationMessageContent {
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
    return "以上是打招呼的内容";
  }

  @override
  MessageContentMeta get meta => friendGreetingContentMeta;

}
