import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import 'media_message_content.dart';
import 'message.dart';
import 'message_content.dart';


// ignore: non_constant_identifier_names
MessageContent CardMessageContentCreator() {
  return CardMessageContent();
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
  late CardType type;
  late String targetId;
  String? name;
  String? displayName;
  String? portrait;

  @override
  MessageContentMeta get meta => cardContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.content != null) {
      targetId = payload.content!;
    } else {
      targetId = "";
    }
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      name = map['n'];
      displayName = map['d'];
      portrait = map['p'];
      if(map['t'] == null) {
        type = CardType.CardType_User;
      } else {
        type = CardType.values[map['t']];
      }
    } else {
      type = CardType.CardType_User;
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();

    payload.content = targetId;
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode({
      'n': name,
      'd': displayName,
      'p': portrait,
      't': type.index,
    })));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    if (displayName != null && displayName!.isNotEmpty) {
      return '[名片]:$displayName';
    }
    return '[名片]';
  }
}
