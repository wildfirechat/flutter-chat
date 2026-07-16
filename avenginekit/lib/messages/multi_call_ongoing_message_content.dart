import 'dart:convert';

import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';

MessageContent MultiCallOngoingMessageContentCreator() {
  return MultiCallOngoingMessageContent();
}

const multiCallOngoingContentMeta = MessageContentMeta(VOIP_CONTENT_MULTI_CALL_ONGOING,
    MessageFlag.NOT_PERSIST, MultiCallOngoingMessageContentCreator);

class MultiCallOngoingMessageContent extends MessageContent {
  late String callId;
  String initiator = '';
  bool audioOnly = false;
  List<String> targets = [];

  MultiCallOngoingMessageContent();

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    callId = payload.content!;
    if (payload.binaryContent != null) {
      try {
        Map<String, dynamic> json = jsonDecode(utf8.decode(payload.binaryContent!));
        initiator = json['initiator'] ?? '';
        audioOnly = json['audioOnly'] == 1 || json['audioOnly'] == true;
        if (json['targets'] != null) {
          targets = List<String>.from(json['targets']);
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
    Map<String, dynamic> data = {
      'initiator': initiator,
      'audioOnly': audioOnly ? 1 : 0,
      'targets': targets,
    };
    payload.binaryContent = utf8.encode(jsonEncode(data));
    return payload;
  }

  @override
  Future<String> digest(Message nb) async {
    return "Multi Call Ongoing";
  }

  @override
  MessageContentMeta get meta => multiCallOngoingContentMeta;
}
