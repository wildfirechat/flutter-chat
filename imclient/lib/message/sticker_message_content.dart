import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import 'media_message_content.dart';
import 'message.dart';
import 'message_content.dart';
// ignore: non_constant_identifier_names
MessageContent StickerMessageContentCreator() {
  return StickerMessageContent();
}

const stickerContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_STICKER,
    MessageFlag.PERSIST_AND_COUNT, StickerMessageContentCreator);

class StickerMessageContent extends MediaMessageContent {
  late int width;
  late int height;

  @override
  MessageContentMeta get meta => stickerContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      width = map['x'];
      height = map['y'];
    } else {
      width = 0;
      height = 0;
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = '[动态表情]';
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode({'x': width, 'y': height})));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[动态表情]';
  }

  @override
  MediaType get mediaType => MediaType.Media_Type_STICKER;
}
