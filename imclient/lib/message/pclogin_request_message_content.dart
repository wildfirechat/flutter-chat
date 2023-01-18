import 'dart:convert';

import '../model/im_constant.dart';
import '../model/message_payload.dart';
import 'media_message_content.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent PCLoginRequestMessageContentCreator() {
  return new PCLoginRequestMessageContent();
}

const pcLoginContentMeta = MessageContentMeta(MESSAGE_PC_LOGIN_REQUSET,
    MessageFlag.NOT_PERSIST, PCLoginRequestMessageContentCreator);

class PCLoginRequestMessageContent extends MediaMessageContent {
  String sessionId;
  PlatformType platform;

  @override
  MessageContentMeta get meta => pcLoginContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    platform = PlatformType.values[map['p']];
    sessionId = map['t'];
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();

    payload.binaryContent =
        utf8.encode(json.encode({'p': platform.index, 't': sessionId}));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return null;
  }
}
