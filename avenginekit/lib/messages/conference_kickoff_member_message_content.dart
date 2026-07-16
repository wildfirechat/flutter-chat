import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';

MessageContent ConferenceKickoffMemberMessageContentCreator() {
  return ConferenceKickoffMemberMessageContent();
}

const conferenceKickoffMemberContentMeta = MessageContentMeta(VOIP_CONTENT_CONFERENCE_KICKOFF_MEMBER,
    MessageFlag.NOT_PERSIST, ConferenceKickoffMemberMessageContentCreator);

class ConferenceKickoffMemberMessageContent extends MessageContent {
  late String callId;

  ConferenceKickoffMemberMessageContent();

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    callId = payload.content!;
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = callId;
    return payload;
  }

  @override
  Future<String> digest(Message nb) async {
    return "Kickoff Member";
  }

  @override
  MessageContentMeta get meta => conferenceKickoffMemberContentMeta;
}
