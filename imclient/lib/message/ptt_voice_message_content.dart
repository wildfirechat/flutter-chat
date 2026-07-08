import 'media_message_content.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent PttVoiceMessageContentCreator() {
  return PttVoiceMessageContent();
}

const pttVoiceContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_PTT_VOICE,
  MessageFlag.PERSIST_AND_COUNT,
  PttVoiceMessageContentCreator,
);

/// PTT语音消息内容
///
/// 对讲机语音消息
/// 消息类型: 23
class PttVoiceMessageContent extends MediaMessageContent {
  /// 对讲频道ID
  String channelId = '';

  @override
  MessageContentMeta get meta => pttVoiceContentMeta;

  @override
  Future<String> digest(Message message) async {
    return '[对讲语音]';
  }

  @override
  MediaType get mediaType => MediaType.Media_Type_VOICE;
}
