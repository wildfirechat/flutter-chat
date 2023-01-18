import 'dart:convert';

import '../model/message_payload.dart';
import 'media_message_content.dart';
import 'message.dart';
import 'message_content.dart';


// ignore: non_constant_identifier_names
MessageContent CardMessageContentCreator() {
  return new CardMessageContent();
}

const cardContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_CARD,
    MessageFlag.PERSIST_AND_COUNT, CardMessageContentCreator);

enum CardType {
  CardType_User,
  CardType_Group,
  CardType_Chatroom,
  CardType_Channel,
}

class CardMessageContent extends MediaMessageContent {
  CardType type;
  String targetId;
  String name;
  String displayName;
  String portrait;

  @override
  MessageContentMeta get meta => cardContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    targetId = payload.content;
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    name = map['n'];
    displayName = map['d'];
    portrait = map['p'];
    type = CardType.values[map['t']];
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();

    payload.content = targetId;
    payload.binaryContent = utf8.encode(json.encode({
      'n': name,
      'd': displayName,
      'p': portrait,
      't': type.index,
    }));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    if (displayName != null && displayName.isNotEmpty) {
      return '[名片]:$displayName';
    }
    return '[名片]';
  }
}
