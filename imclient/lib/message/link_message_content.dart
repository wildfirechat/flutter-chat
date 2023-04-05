import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import 'media_message_content.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent LinkMessageContentCreator() {
  return LinkMessageContent();
}

const linkContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_LINK,
    MessageFlag.PERSIST_AND_COUNT, LinkMessageContentCreator);

class LinkMessageContent extends MediaMessageContent {
  late String title;
  late String contentDigest;
  late String url;
  String? thumbnailUrl;

  @override
  MessageContentMeta get meta => linkContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.searchableContent != null) {
      title = payload.searchableContent!;
    } else {
      title = "";
    }
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      contentDigest = map['d'];
      url = map['u'];
      thumbnailUrl = map['t'];
    } else {
      url = "";
      contentDigest = "";
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();

    payload.searchableContent = title;
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode({
      'd': contentDigest,
      'u': url,
      't': thumbnailUrl,
    })));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    if (title.isNotEmpty) {
      return '[链接]:$title';
    }
    return '[链接]';
  }
}
