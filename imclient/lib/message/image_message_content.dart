import 'dart:convert';
import 'package:image/image.dart';

import '../model/message_payload.dart';
import 'media_message_content.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent ImageMessageContentCreator() {
  return ImageMessageContent();
}

const imageContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_IMAGE, MessageFlag.PERSIST_AND_COUNT, ImageMessageContentCreator);

class ImageMessageContent extends MediaMessageContent {
  Image? thumbnail;
  int width = 0;
  int height = 0;

  @override
  MessageContentMeta get meta => imageContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload.binaryContent != null) thumbnail = decodeJpg(payload.binaryContent!);

    if (payload.content != null) {
      try {
        Map<String, dynamic> json = jsonDecode(payload.content!);
        width = json['w'] ?? 0;
        height = json['h'] ?? 0;
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = '[图片]';
    if (thumbnail != null) {
      payload.binaryContent = encodeJpg(thumbnail!, quality: 35);
    }
    // TODO
    // width and height

    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[图片]';
  }

  @override
  MediaType get mediaType => MediaType.Media_Type_IMAGE;
}
