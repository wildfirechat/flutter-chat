import 'dart:convert';
import 'package:image/image.dart';
import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent LocationMessageContentCreator() {
  return LocationMessageContent();
}

const locationMessageContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_LOCATION,
    MessageFlag.PERSIST_AND_COUNT,
    LocationMessageContentCreator);

class LocationMessageContent extends MessageContent {
  late double latitude;
  late double longitude;
  late String title;
  Image? thumbnail;

  @override
  Future<void> decode(MessagePayload payload) async {
    super.decode(payload);
    if(payload.searchableContent != null) {
      title = payload.searchableContent!;
    } else {
      title = "";
    }
    if(payload.binaryContent != null) {
      thumbnail = decodeJpg(payload.binaryContent!);
    }
    if(payload.content != null) {
      var map = json.decode(payload.content!);
      latitude = map['lat'];
      longitude = map['long'];
    } else {
      latitude = 0;
      longitude = 0;
    }
  }

  @override
  MessageContentMeta get meta => locationMessageContentMeta;

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = title;
    payload.content = json.encode({'lat': latitude, 'long': longitude});
    if(thumbnail != null) {
      payload.binaryContent = encodeJpg(thumbnail!, quality: 35);
    }
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    if (title.isNotEmpty) {
      return '[位置]:$title';
    }

    return '[位置]';
  }
}
