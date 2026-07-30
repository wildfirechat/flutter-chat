import '../model/message_payload.dart';
import 'message_content.dart';

abstract class MediaMessageContent extends MessageContent {
  String? localPath;
  String? remoteUrl;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    localPath = payload.localMediaPath;
    remoteUrl = payload.remoteMediaUrl;
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.localMediaPath = localPath;
    payload.remoteMediaUrl = remoteUrl;
    payload.mediaType = mediaType;
    return payload;
  }

  MediaType get mediaType => MediaType.Media_Type_GENERAL;
}
