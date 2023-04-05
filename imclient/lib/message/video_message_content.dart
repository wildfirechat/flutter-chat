import 'dart:convert';
import 'package:image/image.dart';
import '../model/message_payload.dart';
import 'media_message_content.dart';
import 'message.dart';
import 'message_content.dart';


// ignore: non_constant_identifier_names
MessageContent VideoMessageContentCreator() {
  return VideoMessageContent();
}

const videoContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_VIDEO,
    MessageFlag.PERSIST_AND_COUNT, VideoMessageContentCreator);

class VideoMessageContent extends MediaMessageContent {
  Image? thumbnail;
  late int duration;

  @override
  MessageContentMeta get meta => videoContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload.binaryContent != null) {
      thumbnail = decodeJpg(payload.binaryContent!);
    }
    duration = 0;
    if (payload.content != null) {
      var map = json.decode(payload.content!);
      duration = map['duration'];
      duration ??= map['d'];
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = '[视频]';
    if(thumbnail != null) {
      payload.binaryContent = encodeJpg(thumbnail!, quality: 35);
    }
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
