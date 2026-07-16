import 'dart:convert';

import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';

MessageContent JoinCallRequestMessageContentCreator() {
  return JoinCallRequestMessageContent();
}

const joinCallRequestContentMeta = MessageContentMeta(VOIP_CONTENT_JOIN_CALL_REQUEST,
    MessageFlag.NOT_PERSIST, JoinCallRequestMessageContentCreator);

class JoinCallRequestMessageContent extends MessageContent {
  late String callId;
  String clientId = '';

  JoinCallRequestMessageContent();

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    callId = payload.content!;
    if (payload.binaryContent != null) {
      try {
        Map<String, dynamic> json = jsonDecode(utf8.decode(payload.binaryContent!));
        clientId = json['clientId'] ?? '';
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = callId;
    Map<String, dynamic> data = {
      'clientId': clientId,
    };
    payload.binaryContent = utf8.encode(jsonEncode(data));
    return payload;
  }

  @override
  Future<String> digest(Message nb) async {
    return "";
  }

  @override
  MessageContentMeta get meta => joinCallRequestContentMeta;
}
