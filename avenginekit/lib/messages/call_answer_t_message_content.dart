import 'dart:convert';

import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';

MessageContent CallAnswerTMessageContentCreator() {
  return CallAnswerTMessageContent();
}

const callAnswerTContentMeta = MessageContentMeta(VOIP_CONTENT_TYPE_ACCEPT_T,
    MessageFlag.NOT_PERSIST, CallAnswerTMessageContentCreator);

class CallAnswerTMessageContent extends MessageContent {
  late String callId;
  bool audioOnly = false;

  CallAnswerTMessageContent();

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    callId = payload.content!;
    if (payload.binaryContent != null) {
      try {
        String str = utf8.decode(payload.binaryContent!);
        audioOnly = str == '1';
      } catch (e) {
        audioOnly = false;
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = callId;
    payload.binaryContent = utf8.encode(audioOnly ? '1' : '0');
    return payload;
  }

  @override
  Future<String> digest(Message nb) async {
    return "";
  }

  @override
  MessageContentMeta get meta => callAnswerTContentMeta;
}
