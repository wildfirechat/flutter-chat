import 'dart:convert';
import 'dart:typed_data';

import '../model/im_constant.dart';
import '../model/message_payload.dart';
import 'media_message_content.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent PCLoginRequestMessageContentCreator() {
  return PCLoginRequestMessageContent();
}

const pcLoginContentMeta = MessageContentMeta(MESSAGE_PC_LOGIN_REQUSET,
    MessageFlag.NOT_PERSIST, PCLoginRequestMessageContentCreator);

class PCLoginRequestMessageContent extends MediaMessageContent {
  late String sessionId;
  late PlatformType platform;

  @override
  MessageContentMeta get meta => pcLoginContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      platform = PlatformType.values[map['p']];
      sessionId = map['t'];
    } else {
      platform = PlatformType.PlatformType_UNSET;
      sessionId = "";
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.binaryContent =
        Uint8List.fromList(utf8.encode(json.encode({'p': platform.index, 't': sessionId})));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return "";
  }
}
