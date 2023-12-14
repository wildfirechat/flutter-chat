import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import 'media_message_content.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent SoundMessageContentCreator() {
  return SoundMessageContent();
}

const soundContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_SOUND,
    MessageFlag.PERSIST_AND_COUNT, SoundMessageContentCreator);


class SoundMessageContent extends MediaMessageContent {
  late int duration;

  @override
  MessageContentMeta get meta => soundContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload.content != null) {
      Map<dynamic, dynamic> map = json.decode(payload.content!);
      duration = map['duration'];
    } else {
      duration = 0;
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = '[语音]';
    payload.content = json.encode({'duration':duration});
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[语音]';
  }

  @override
  MediaType get mediaType => MediaType.Media_Type_VOICE;
}