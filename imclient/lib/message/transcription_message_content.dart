import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent TranscriptionMessageContentCreator() {
  return TranscriptionMessageContent();
}

const transcriptionContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_TRANSCRIPTION,
  MessageFlag.PERSIST,
  TranscriptionMessageContentCreator,
);

/// 转换/透传消息内容
///
/// 用于语音转文字等转换内容，不参加计数
/// 消息类型: 26
class TranscriptionMessageContent extends MessageContent {
  /// 对应的原始消息UID
  int targetMessageUid = 0;

  /// 转换内容
  String text = '';

  /// 转换类型: 1=语音转文字
  int type = 1;

  @override
  MessageContentMeta get meta => transcriptionContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    text = payload.searchableContent ?? '';

    if (payload.binaryContent != null) {
      try {
        Map<dynamic, dynamic> json =
            jsonDecode(utf8.decode(payload.binaryContent!));
        targetMessageUid = json['m'] ?? 0;
        type = json['t'] ?? 1;
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = text;

    Map<String, dynamic> jsonObject = {
      'm': targetMessageUid,
      't': type,
    };
    payload.binaryContent =
        Uint8List.fromList(utf8.encode(jsonEncode(jsonObject)));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return text.isNotEmpty ? text : '[转换消息]';
  }
}
