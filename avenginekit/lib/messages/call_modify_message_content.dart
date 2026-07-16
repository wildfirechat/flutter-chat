import 'dart:convert';

import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';
MessageContent CallModifyMessageContentCreator() {
  return CallModifyMessageContent();
}

const callModifyContentMeta = MessageContentMeta(VOIP_CONTENT_TYPE_MODIFY,
    MessageFlag.NOT_PERSIST, CallModifyMessageContentCreator);
class CallModifyMessageContent extends MessageContent {
  late String callId;
  bool audioOnly = false;

  CallModifyMessageContent();

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    callId = payload.content!;
    if (payload.binaryContent != null && payload.binaryContent!.isNotEmpty) {
      try {
        final value = int.tryParse(utf8.decode(payload.binaryContent!));
        if (value != null) {
          audioOnly = value > 0;
        }
      } catch (e) {
        // ignore
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
    return "Modify Call";
  }

  @override
  MessageContentMeta get meta => callModifyContentMeta;
}
