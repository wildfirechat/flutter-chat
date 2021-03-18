import 'dart:convert';

import 'package:flutter_imclient/message/media_message_content.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';

// ignore: non_constant_identifier_names
MessageContent LinkMessageContentCreator() {
  return new LinkMessageContent();
}

const linkContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_LINK,
    MessageFlag.PERSIST_AND_COUNT, LinkMessageContentCreator);

class LinkMessageContent extends MediaMessageContent {
  String title;
  String contentDigest;
  String url;
  String thumbnailUrl;

  @override
  MessageContentMeta get meta => linkContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    title = payload.searchableContent;
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    contentDigest = map['d'];
    url = map['u'];
    thumbnailUrl = map['t'];
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();

    payload.searchableContent = title;
    payload.binaryContent = utf8.encode(json.encode({
      'd': contentDigest,
      'u': url,
      't': thumbnailUrl,
    }));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    if (title != null && title.isNotEmpty) {
      return '[链接]:$title';
    }
    return '[链接]';
  }
}
