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
MessageContent KickoffGroupMemberNotificationContentCreator() {
  return KickoffGroupMemberNotificationContent();
}

const kickoffGroupMemberNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_KICKOF_GROUP_MEMBER,
    MessageFlag.PERSIST,
    KickoffGroupMemberNotificationContentCreator);

class KickoffGroupMemberNotificationContent extends NotificationMessageContent {
  late String groupId;
  late String operateUser;
  late List<String> kickedMembers;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      operateUser = map['o'];
      groupId = map['g'];
      kickedMembers = Tools.convertDynamicList(map['ms']);
    } else {
      operateUser = "";
      groupId = "";
      kickedMembers = [];
    }
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    Map<String, dynamic> map = {};
    map['o'] = operateUser;
    map['g'] = groupId;
    map['ms'] = kickedMembers;
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
      if (userInfo != null) {
        formatMsg = userInfo.getReadableName();
      } else {
        formatMsg = operateUser;
      }
    }

    formatMsg = '$formatMsg 把';

    for (int i = 0; i < kickedMembers.length; ++i) {
      String memberId = kickedMembers[i];
      if (memberId == Imclient.currentUserId) {
        formatMsg = '$formatMsg 你';
      } else {
        UserInfo? userInfo =
            await Imclient.getUserInfo(memberId, groupId: groupId);
        if (userInfo != null) {
          formatMsg = '$formatMsg ${userInfo.getReadableName()}';
        } else {
          formatMsg = '$formatMsg $operateUser';
        }
      }
    }

    formatMsg = '$formatMsg 移出群聊';

    return formatMsg;
  }

  @override
  MessageContentMeta get meta => kickoffGroupMemberNotificationContentMeta;
}
