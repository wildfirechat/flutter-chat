import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart';

import 'package:flutter/painting.dart';
import 'package:flutter_imclient/message/media_message_content.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/message/message.dart';

// ignore: non_constant_identifier_names
MessageContent ImageMessageContentCreator() {
  return new ImageMessageContent();
}

const imageContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_IMAGE,
    MessageFlag.PERSIST_AND_COUNT, ImageMessageContentCreator);


class ImageMessageContent extends MediaMessageContent {
  Image thumbnail;

  @override
  MessageContentMeta get meta => imageContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload.binaryContent != null) thumbnail = decodeJpg(payload.binaryContent);
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    payload.searchableContent = '[图片]';
    payload.binaryContent = encodeJpg(thumbnail, quality: 35);

    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[图片]';
  }

  @override
  MediaType get mediaType => MediaType.Media_Type_IMAGE;
}