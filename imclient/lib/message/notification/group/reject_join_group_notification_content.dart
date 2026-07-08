import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent RejectJoinGroupNotificationContentCreator() {
  return RejectJoinGroupNotificationContent();
}

const rejectJoinGroupNotificationContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_REJECT_JOIN_GROUP,
  MessageFlag.PERSIST,
  RejectJoinGroupNotificationContentCreator,
);

/// 拒绝加入群组通知消息
///
/// 群管理拒绝用户的加群请求
/// 消息类型: 125
class RejectJoinGroupNotificationContent
    extends NotificationMessageContent {
  late String groupId;
  late String operateUser;
  late String rejectedMember;
  String reason = '';

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload.binaryContent != null) {
      Map<dynamic, dynamic> map =
          json.decode(utf8.decode(payload.binaryContent!));
      operateUser = map['o'] ?? '';
      groupId = map['g'] ?? '';
      rejectedMember = map['m'] ?? '';
      reason = map['r'] ?? '';
    }
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    Map<String, dynamic> map = {
      'o': operateUser,
      'g': groupId,
      'm': rejectedMember,
      'r': reason,
    };
    payload.binaryContent =
        Uint8List.fromList(utf8.encode(json.encode(map)));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String formatMsg;
    if (operateUser == Imclient.currentUserId) {
      formatMsg = '你';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(operateUser, groupId: groupId);
      formatMsg = userInfo?.getReadableName() ?? operateUser;
    }

    String targetName = rejectedMember;
    if (rejectedMember == Imclient.currentUserId) {
      targetName = '你';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(rejectedMember, groupId: groupId);
      targetName = userInfo?.getReadableName() ?? rejectedMember;
    }

    formatMsg = '$formatMsg 拒绝了 $targetName 的加群请求';
    if (reason.isNotEmpty) {
      formatMsg = '$formatMsg: $reason';
    }

    return formatMsg;
  }

  @override
  MessageContentMeta get meta => rejectJoinGroupNotificationContentMeta;
}
