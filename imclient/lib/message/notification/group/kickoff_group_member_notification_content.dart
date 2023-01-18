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
  return new KickoffGroupMemberNotificationContent();
}

const kickoffGroupMemberNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_KICKOF_GROUP_MEMBER,
    MessageFlag.PERSIST,
    KickoffGroupMemberNotificationContentCreator);

class KickoffGroupMemberNotificationContent extends NotificationMessageContent {
  String groupId;
  String operateUser;
  List<String> kickedMembers;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    operateUser = map['o'];
    groupId = map['g'];
    kickedMembers = Tools.convertDynamicList(map['ms']);
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    Map<String, dynamic> map = new Map();
    map['o'] = operateUser;
    map['g'] = groupId;
    map['ms'] = kickedMembers;
    payload.binaryContent = new Uint8List.fromList(json.encode(map).codeUnits);
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String formatMsg;
    if (operateUser == await Imclient.currentUserId) {
      formatMsg = '你';
    } else {
      UserInfo userInfo =
          await Imclient.getUserInfo(operateUser, groupId: groupId);
      if (userInfo != null) {
        if (userInfo.friendAlias != null && userInfo.friendAlias.isNotEmpty) {
          formatMsg = '${userInfo.friendAlias}';
        } else if (userInfo.groupAlias != null &&
            userInfo.groupAlias.isNotEmpty) {
          formatMsg = '${userInfo.groupAlias}';
        } else if (userInfo.displayName != null &&
            userInfo.displayName.isNotEmpty) {
          formatMsg = '${userInfo.displayName}';
        } else {
          formatMsg = '$operateUser';
        }
      } else {
        formatMsg = '$operateUser';
      }
    }

    formatMsg = '$formatMsg 把';

    for (int i = 0; i < kickedMembers.length; ++i) {
      String memberId = kickedMembers[i];
      if (memberId == await Imclient.currentUserId) {
        formatMsg = '$formatMsg 你';
      } else {
        UserInfo userInfo =
            await Imclient.getUserInfo(memberId, groupId: groupId);
        if (userInfo != null) {
          if (userInfo.friendAlias != null && userInfo.friendAlias.isNotEmpty) {
            formatMsg = '$formatMsg ${userInfo.friendAlias}';
          } else if (userInfo.groupAlias != null &&
              userInfo.groupAlias.isNotEmpty) {
            formatMsg = '$formatMsg ${userInfo.groupAlias}';
          } else if (userInfo.displayName != null &&
              userInfo.displayName.isNotEmpty) {
            formatMsg = '$formatMsg ${userInfo.displayName}';
          } else {
            formatMsg = '$formatMsg $operateUser';
          }
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
