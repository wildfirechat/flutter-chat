import 'dart:convert';

import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';

MessageContent ConferenceCommandMessageContentCreator() {
  return ConferenceCommandMessageContent();
}

const conferenceCommandContentMeta = MessageContentMeta(VOIP_CONTENT_CONFERENCE_COMMAND,
    MessageFlag.NOT_PERSIST, ConferenceCommandMessageContentCreator);

class ConferenceCommandMessageContent extends MessageContent {
  late String callId;
  int command = 0;
  String targetUserId = '';
  bool boolValue = false;

  ConferenceCommandMessageContent();

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    callId = payload.content!;
    if (payload.binaryContent != null) {
      try {
        Map<String, dynamic> json = jsonDecode(utf8.decode(payload.binaryContent!));
        command = json['cmd'] ?? 0;
        targetUserId = json['u'] ?? '';
        boolValue = json['b'] == 1 || json['b'] == true;
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = callId;
    payload.binaryContent = utf8.encode(jsonEncode({
      'cmd': command,
      'u': targetUserId,
      'b': boolValue ? 1 : 0,
    }));
    return payload;
  }

  @override
  Future<String> digest(Message nb) async {
    return "";
  }

  @override
  MessageContentMeta get meta => conferenceCommandContentMeta;
}
