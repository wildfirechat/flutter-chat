import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';

class MediaMessageContent extends MessageContent {
  String localPath;
  String remoteUrl;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    localPath = payload.localMediaPath;
    remoteUrl = payload.remoteMediaUrl;
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    payload.localMediaPath = localPath;
    payload.remoteMediaUrl = remoteUrl;
    payload.mediaType = mediaType;
    return payload;
  }

  MediaType get mediaType => MediaType.Media_Type_GENERAL;
}