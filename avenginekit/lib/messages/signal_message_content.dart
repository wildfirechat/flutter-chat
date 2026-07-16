import 'dart:convert';

import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';



MessageContent SignalMessageContentCreator() {
  return SignalMessageContent(callId: '', payload: '');
}

const signalContentMeta = MessageContentMeta(VOIP_CONTENT_TYPE_SIGNAL,
    MessageFlag.TRANSPARENT, SignalMessageContentCreator);


class SignalMessageContent extends MessageContent {
  String callId;
  String payload; 

  SignalMessageContent({required this.callId, required this.payload});

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    this.callId = payload.content!;
    this.payload = utf8.decode(payload.binaryContent!);
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = this.callId;
    payload.binaryContent = utf8.encode(this.payload);
    return payload;
  }

  @override
  Future<String> digest(Message nb) async {
    return "Signal";
  }

  @override
  MessageContentMeta get meta => signalContentMeta;

}
