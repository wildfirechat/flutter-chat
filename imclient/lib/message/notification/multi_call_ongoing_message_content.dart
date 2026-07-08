import 'dart:convert';
import 'dart:typed_data';

import '../../model/message_payload.dart';
import '../message.dart';
import '../message_content.dart';
import 'notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent MultiCallOngoingContentCreator() {
  return MultiCallOngoingMessageContent();
}

const multiCallOngoingContentMeta = MessageContentMeta(
  VOIP_CONTENT_MULTI_CALL_ONGOING,
  MessageFlag.PERSIST,
  MultiCallOngoingContentCreator,
);

/// 多人通话进行中消息内容
///
/// 显示群聊中正在进行的多人通话状态，可点击加入
/// 消息类型: 416
class MultiCallOngoingMessageContent extends NotificationMessageContent {
  /// 通话ID
  String callId = '';

  /// 发起者ID
  String initiatorId = '';

  /// 当前参会人列表
  List<String> participants = [];

  /// 是否音频通话
  bool isAudioOnly = false;

  /// 通话开始时间
  int startTime = 0;

  @override
  MessageContentMeta get meta => multiCallOngoingContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload.binaryContent != null) {
      try {
        Map<dynamic, dynamic> json =
            jsonDecode(utf8.decode(payload.binaryContent!));
        callId = json['c'] ?? '';
        initiatorId = json['i'] ?? '';
        isAudioOnly = json['a'] ?? false;
        startTime = json['st'] ?? 0;

        List<dynamic>? ps = json['ps'];
        if (ps != null) {
          participants = ps.map((e) => e.toString()).toList();
        }
      } catch (e) {
        callId = '';
        initiatorId = '';
        participants = [];
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();

    Map<String, dynamic> jsonObject = {
      'c': callId,
      'i': initiatorId,
      'a': isAudioOnly,
      'st': startTime,
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
    return '${isAudioOnly ? '语音' : '视频'}通话进行中';
  }
}
