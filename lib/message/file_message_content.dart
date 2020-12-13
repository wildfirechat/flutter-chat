import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart';

import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/media_message_content.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';

// ignore: non_constant_identifier_names
MessageContent FileMessageContentCreator() {
  return new FileMessageContent();
}

const fileContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_FILE,
    MessageFlag.PERSIST_AND_COUNT, FileMessageContentCreator);


class FileMessageContent extends MediaMessageContent {
  String name;
  int size;

  @override
  MessageContentMeta get meta => fileContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    name = payload.searchableContent;
    size = int.parse(payload.content);
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    payload.searchableContent = name;
    payload.content = size.toString();
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    if(name != null && name.isNotEmpty) {
      return '[文件]:$name';
    }
    return '[文件]';
  }

  @override
  MediaType get mediaType => MediaType.Media_Type_FILE;
}