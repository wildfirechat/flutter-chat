import 'dart:convert';
import 'dart:typed_data';

import 'package:imclient/tools.dart';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent KickoffGroupMemberVisibleNotificationContentCreator() {
  return KickoffGroupMemberVisibleNotificationContent();
}

const kickoffGroupMemberVisibleNotificationContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_KICKOF_GROUP_MEMBER_VISIBLE,
  MessageFlag.PERSIST,
  KickoffGroupMemberVisibleNotificationContentCreator,
);

/// 踢出群成员的可见通知消息
///
/// 群成员被踢出后，对所有成员可见的通知
/// 消息类型: 120
class KickoffGroupMemberVisibleNotificationContent
    extends NotificationMessageContent {
  late String groupId;
  late String operateUser;
  late List<String> kickedMembers;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload.binaryContent != null) {
      Map<dynamic, dynamic> map =
          json.decode(utf8.decode(payload.binaryContent!));
      operateUser = map['o'];
      groupId = map['g'];
      kickedMembers = Tools.convertDynamicList(map['ms']);
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
      'ms': kickedMembers,
    };
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));
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
    formatMsg = '$formatMsg 把';

    List<String> names = [];
    for (String memberId in kickedMembers) {
      if (memberId == Imclient.currentUserId) {
        names.add('你');
      } else {
        UserInfo? userInfo =
            await Imclient.getUserInfo(memberId, groupId: groupId);
        names.add(userInfo?.getReadableName() ?? memberId);
      }
    }
    formatMsg = '$formatMsg ${names.join('、')} 移出群聊';

    return formatMsg;
  }

  @override
  MessageContentMeta get meta =>
      kickoffGroupMemberVisibleNotificationContentMeta;
}
