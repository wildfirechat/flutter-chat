import 'dart:convert';

import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:image/image.dart';

// ignore: non_constant_identifier_names
MessageContent LocationMessageContentCreator() {
  return new LocationMessageContent();
}

const locationMessageContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_LOCATION,
    MessageFlag.PERSIST_AND_COUNT,
    LocationMessageContentCreator);

class LocationMessageContent extends MessageContent {
  double latitude;
  double longitude;
  String title;
  Image thumbnail;

  @override
  Future<void> decode(MessagePayload payload) async {
    super.decode(payload);
    title = payload.searchableContent;
    thumbnail = decodeJpg(payload.binaryContent);
    var map = json.decode(payload.content);
    latitude = map['lat'];
    longitude = map['long'];
  }

  @override
  MessageContentMeta get meta => locationMessageContentMeta;

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    payload.searchableContent = title;
    payload.content = json.encode({'lat': latitude, 'long': longitude});
    payload.binaryContent = encodeJpg(thumbnail, quality: 35);
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    if (title != null && title.isNotEmpty) {
      return '[位置]:$title';
    }

    return '[位置]';
  }
}
