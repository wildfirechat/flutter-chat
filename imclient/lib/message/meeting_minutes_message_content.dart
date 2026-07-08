import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent MeetingMinutesMessageContentCreator() {
  return MeetingMinutesMessageContent();
}

const meetingMinutesContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_MEETING_MINUTES,
  MessageFlag.PERSIST_AND_COUNT,
  MeetingMinutesMessageContentCreator,
);

/// 会议纪要消息内容
///
/// 用于展示会议纪要，包含会议主题、时间、参会人、纪要内容等
/// 消息类型: 25
class MeetingMinutesMessageContent extends MessageContent {
  /// 会议主题
  String subject = '';

  /// 会议开始时间
  int startTime = 0;

  /// 会议时长（秒）
  int duration = 0;

  /// 会议创建者
  String creatorId = '';

  /// 纪要内容
  String content = '';

  /// 会议链接
  String url = '';

  @override
  MessageContentMeta get meta => meetingMinutesContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    subject = payload.searchableContent ?? '';

    if (payload.binaryContent != null) {
      try {
        Map<dynamic, dynamic> json =
            jsonDecode(utf8.decode(payload.binaryContent!));
        startTime = json['st'] ?? 0;
        duration = json['dr'] ?? 0;
        creatorId = json['c'] ?? '';
        content = json['ct'] ?? '';
        url = json['u'] ?? '';
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = subject;

    Map<String, dynamic> jsonObject = {
      'st': startTime,
      'dr': duration,
      'c': creatorId,
      'ct': content,
      'u': url,
    };
    payload.binaryContent =
        Uint8List.fromList(utf8.encode(jsonEncode(jsonObject)));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[会议纪要] $subject';
  }
}
