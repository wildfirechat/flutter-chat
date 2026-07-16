import 'dart:convert';

import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';

MessageContent MuteVideoMessageContentCreator() {
  return MuteVideoMessageContent();
}

const muteVideoContentMeta = MessageContentMeta(VOIP_CONTENT_MUTE_VIDEO,
    MessageFlag.NOT_PERSIST, MuteVideoMessageContentCreator);

class MuteVideoMessageContent extends MessageContent {
  late String callId;
  late bool videoMuted;
  List<String>? existParticipants;

  MuteVideoMessageContent();

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    callId = payload.content!;
    if (payload.binaryContent != null) {
      try {
        Map<String, dynamic> json = jsonDecode(utf8.decode(payload.binaryContent!));
        videoMuted = json['videoMuted'] == 1 || json['videoMuted'] == true;
        existParticipants = json['existParticipants'];
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
      'videoMuted': videoMuted ? 1 : 0,
      'existParticipants': existParticipants
    };
    payload.binaryContent = utf8.encode(jsonEncode(data));
    return payload;
  }

  @override
  Future<String> digest(Message nb) async {
    return "Mute Video";
  }

  @override
  MessageContentMeta get meta => muteVideoContentMeta;

}
