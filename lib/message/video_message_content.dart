import 'dart:convert';

import 'package:flutter_imclient/message/media_message_content.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:image/image.dart';

// ignore: non_constant_identifier_names
MessageContent VideoMessageContentCreator() {
  return new VideoMessageContent();
}

const videoContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_VIDEO,
    MessageFlag.PERSIST_AND_COUNT, VideoMessageContentCreator);

class VideoMessageContent extends MediaMessageContent {
  Image thumbnail;
  int duration;

  @override
  MessageContentMeta get meta => videoContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload?.binaryContent != null) {
      thumbnail = decodeJpg(payload.binaryContent);
    }
    if (payload?.content != null) {
      var map = json.decode(payload.content);
      duration = map['duration'];
      if (duration == null) {
        duration = map['d'];
      }
    }
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    payload.searchableContent = '[视频]';
    payload.binaryContent = encodeJpg(thumbnail, quality: 35);
    payload.content = json.encode({'duration': duration, 'd': duration});
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[视频]';
  }

  @override
  MediaType get mediaType => MediaType.Media_Type_VIDEO;
}
