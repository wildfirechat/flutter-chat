import 'dart:typed_data';

import '../message/message_content.dart';

class MessagePayload {
  MessagePayload(
      {this.mentionedType = 0,
      this.mediaType = MediaType.Media_Type_GENERAL});
  late int contentType;
  String? searchableContent;
  String? pushContent;
  String? pushData;
  String? content;
  Uint8List? binaryContent;
  String? localContent;
  int mentionedType;
  List<String>? mentionedTargets;

  MediaType mediaType;
  String? remoteMediaUrl;
  String? localMediaPath;

  String? extra;
}
