import 'dart:convert';

import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';

MessageContent ConferenceChangeModeMessageContentCreator() {
  return ConferenceChangeModeMessageContent();
}

const conferenceChangeModeContentMeta = MessageContentMeta(VOIP_CONTENT_CONFERENCE_CHANGE_MODE,
    MessageFlag.NOT_PERSIST, ConferenceChangeModeMessageContentCreator);

class ConferenceChangeModeMessageContent extends MessageContent {
  late String callId;
  bool audience = false;

  ConferenceChangeModeMessageContent();

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    callId = payload.content!;
    if (payload.binaryContent != null) {
      try {
        Map<String, dynamic> json = jsonDecode(utf8.decode(payload.binaryContent!));
        audience = json['a'] == 1 || json['a'] == true;
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
      'a': audience ? 1 : 0,
    };
    payload.binaryContent = utf8.encode(jsonEncode(data));
    return payload;
  }

  @override
  Future<String> digest(Message nb) async {
    return "Change Mode";
  }

  @override
  MessageContentMeta get meta => conferenceChangeModeContentMeta;
}
