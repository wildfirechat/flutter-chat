import 'dart:convert';

import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';



MessageContent AnswerMessageContentCreator() {
  return AnswerMessageContent(callId: '');
}

const answerContentMeta = MessageContentMeta(VOIP_CONTENT_TYPE_ACCEPT, MessageFlag.NOT_PERSIST, AnswerMessageContentCreator);

class AnswerMessageContent extends MessageContent {
  String callId = '';
  bool audioOnly = false;
  int? inviteMsgUid;

  AnswerMessageContent({required this.callId, this.audioOnly = false, this.inviteMsgUid});

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    callId = payload.content!;
    try {
      audioOnly = int.parse(utf8.decode(payload.binaryContent!)) > 0;
    } catch (e) {
      audioOnly = false;
    }

    if (payload.extra != null) {
      try {
        Map<String, dynamic> json = jsonDecode(payload.extra!);
        inviteMsgUid = json['u'];
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = callId;
    payload.binaryContent = utf8.encode(audioOnly ? "1" : "0");
    if (inviteMsgUid != null) {
      payload.extra = jsonEncode({'u': inviteMsgUid});
    }
    return payload;
  }

  @override
  Future<String> digest(Message nb) async {
    return "Answer Call";
  }

  @override
  MessageContentMeta get meta => answerContentMeta;
}
