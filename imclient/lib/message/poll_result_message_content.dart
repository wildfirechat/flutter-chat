import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent PollResultMessageContentCreator() {
  return PollResultMessageContent();
}

const pollResultContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_POLL_RESULT,
  MessageFlag.PERSIST,
  PollResultMessageContentCreator,
);

/// 投票结果消息内容
///
/// 用于展示投票结果，包含各项得票统计
/// 消息类型: 19
class PollResultMessageContent extends MessageContent {
  /// 投票ID
  String pollId = '';

  /// 投票标题
  String title = '';

  /// 各项得票数 {选项ID: 得票数}
  Map<String, int> results = {};

  /// 总投票人数
  int totalVoters = 0;

  /// 是否已结束
  bool ended = false;

  @override
  MessageContentMeta get meta => pollResultContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    title = payload.searchableContent ?? '';

    if (payload.binaryContent != null) {
      try {
        Map<dynamic, dynamic> json =
            jsonDecode(utf8.decode(payload.binaryContent!));
        pollId = json['pollId'] ?? '';
        totalVoters = json['totalVoters'] ?? 0;
        ended = json['ended'] ?? false;

        Map<dynamic, dynamic>? r = json['results'];
        if (r != null) {
          results = r.map((k, v) => MapEntry(k.toString(), v as int));
        }
      } catch (e) {
        pollId = '';
        results = {};
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = title;

    Map<String, dynamic> jsonObject = {
      'pollId': pollId,
      'totalVoters': totalVoters,
      'ended': ended,
      'results': results,
    };
    payload.binaryContent =
        Uint8List.fromList(utf8.encode(jsonEncode(jsonObject)));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[投票结果] $title';
  }
}
