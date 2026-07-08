import 'dart:convert';
import 'dart:typed_data';

import '../../model/message_payload.dart';
import '../message.dart';
import '../message_content.dart';
import 'notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent ConferenceInviteContentCreator() {
  return ConferenceInviteMessageContent();
}

const conferenceInviteContentMeta = MessageContentMeta(
  VOIP_CONTENT_CONFERENCE_INVITE,
  MessageFlag.PERSIST,
  ConferenceInviteContentCreator,
);

/// 会议邀请消息内容
///
/// 邀请用户加入多人会议
/// 消息类型: 408
class ConferenceInviteMessageContent extends NotificationMessageContent {
  /// 会议ID
  String conferenceId = '';

  /// 邀请方用户ID
  String inviterId = '';

  /// 会议主题
  String subject = '';

  /// 邀请的参会人列表
  List<String> participants = [];

  /// 会议密码
  String password = '';

  /// 音频是否开启
  bool audioEnabled = true;

  /// 视频是否开启
  bool videoEnabled = false;

  @override
  MessageContentMeta get meta => conferenceInviteContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    subject = payload.searchableContent ?? '';

    if (payload.binaryContent != null) {
      try {
        Map<dynamic, dynamic> json =
            jsonDecode(utf8.decode(payload.binaryContent!));
        conferenceId = json['c'] ?? '';
        inviterId = json['i'] ?? '';
        password = json['p'] ?? '';
        audioEnabled = json['a'] ?? true;
        videoEnabled = json['v'] ?? false;

        List<dynamic>? ps = json['ps'];
        if (ps != null) {
          participants = ps.map((e) => e.toString()).toList();
        }
      } catch (e) {
        conferenceId = '';
        inviterId = '';
        participants = [];
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = subject;

    Map<String, dynamic> jsonObject = {
      'c': conferenceId,
      'i': inviterId,
      'p': password,
      'a': audioEnabled,
      'v': videoEnabled,
      'ps': participants,
    };
    payload.binaryContent =
        Uint8List.fromList(utf8.encode(jsonEncode(jsonObject)));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  Future<String> formatNotification(Message message) async {
    return '[会议邀请] $subject';
  }
}
