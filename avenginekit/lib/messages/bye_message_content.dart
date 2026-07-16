import 'dart:convert';

import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';


MessageContent ByeMessageContentCreator() {
  return ByeMessageContent(callId: '');
}

const byeContentMeta = MessageContentMeta(VOIP_CONTENT_TYPE_END,
    MessageFlag.NOT_PERSIST, ByeMessageContentCreator);


class ByeMessageContent extends MessageContent {
  String callId;
  int reason;
  int? inviteMsgUid;

  ByeMessageContent({required this.callId, this.reason = 0, this.inviteMsgUid});

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    this.callId = payload.content!;
    if (payload.binaryContent != null) {
      try {
        Map<String, dynamic> json = jsonDecode(utf8.decode(payload.binaryContent!));
        reason = json['r'] ?? 0;
        inviteMsgUid = json['u'];
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = this.callId;
    Map<String, dynamic> json = {'c': callId, 'r': reason};
    if(inviteMsgUid != null) {
      json['u'] = inviteMsgUid;
    }
    String jsonStr = jsonEncode(json);
    payload.binaryContent = utf8.encode(jsonStr);
    payload.pushData = jsonStr;
    return payload;
  }

  @override
  Future<String> digest(Message nb) async {
    return "Bye";
  }

  @override
  MessageContentMeta get meta => byeContentMeta;
}
