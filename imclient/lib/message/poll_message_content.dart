import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent PollMessageContentCreator() {
  return PollMessageContent();
}

const pollContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_POLL,
  MessageFlag.PERSIST_AND_COUNT,
  PollMessageContentCreator,
);

/// 投票消息内容
/// 
/// 用于表示群聊中的投票创建消息
/// 消息类型: 18
class PollMessageContent extends MessageContent {
  /// 投票ID
  late String pollId;

  /// 群ID
  late String groupId;

  /// 创建者ID
  late String creatorId;

  /// 投票标题
  late String title;

  /// 投票描述
  String desc = '';

  /// 可见性: 1=仅群内, 2=公开
  int visibility = 1;

  /// 类型: 1=单选, 2=多选
  int type = 1;

  /// 是否匿名: 0=实名, 1=匿名
  int anonymous = 0;

  /// 状态: 0=进行中, 1=已结束
  int status = 0;

  /// 截止时间（毫秒时间戳，0表示无截止时间）
  int endTime = 0;

  /// 总票数
  int totalVotes = 0;

  @override
  MessageContentMeta get meta => pollContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    title = payload.searchableContent ?? '';

    if (payload.binaryContent != null) {
      try {
        Map<dynamic, dynamic> json = jsonDecode(utf8.decode(payload.binaryContent!));
        pollId = json['pollId'] ?? '';
        groupId = json['groupId'] ?? '';
        creatorId = json['creatorId'] ?? '';
        title = json['title'] ?? title;
        desc = json['desc'] ?? '';
        visibility = json['visibility'] ?? 1;
        type = json['type'] ?? 1;
        anonymous = json['anonymous'] ?? 0;
        status = json['status'] ?? 0;
        endTime = json['endTime'] ?? 0;
        totalVotes = json['totalVotes'] ?? 0;
      } catch (e) {
        pollId = '';
        groupId = '';
        creatorId = '';
      }
    } else {
      pollId = '';
      groupId = '';
      creatorId = '';
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = title;

    Map<String, dynamic> jsonObject = {
      'pollId': pollId,
      'groupId': groupId,
      'creatorId': creatorId,
      'title': title,
      'visibility': visibility,
      'type': type,
      'anonymous': anonymous,
      'status': status,
      'endTime': endTime,
      'totalVotes': totalVotes,
    };

    if (desc.isNotEmpty) {
      jsonObject['desc'] = desc;
    }

    payload.binaryContent = Uint8List.fromList(utf8.encode(jsonEncode(jsonObject)));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[投票] $title';
  }

  /// 是否已过期
  bool get isExpired {
    if (endTime > 0) {
      return endTime < DateTime.now().millisecondsSinceEpoch;
    }
    return false;
  }

  /// 是否已结束（手动关闭或过期）
  bool get isEnded => status == 1 || isExpired;

  /// 获取剩余时间文本
  String? getRemainingTimeText() {
    if (status == 1) return '已结束';
    if (endTime <= 0) return null;

    int now = DateTime.now().millisecondsSinceEpoch;
    int remaining = endTime - now;

    if (remaining <= 0) return '已过期';

    int minutes = remaining ~/ 60000;
    int hours = minutes ~/ 60;
    int days = hours ~/ 24;

    if (days > 0) return '还剩$days天';
    if (hours > 0) return '还剩$hours小时';
    return '还剩$minutes分钟';
  }
}
