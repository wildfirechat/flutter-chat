import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../../tools.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';


// ignore: non_constant_identifier_names
MessageContent AddGroupMemberNotificationContentCreator() {
  return AddGroupMemberNotificationContent();
}

const addGroupMemberNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_ADD_GROUP_MEMBER,
    MessageFlag.PERSIST,
    AddGroupMemberNotificationContentCreator);

class AddGroupMemberNotificationContent extends NotificationMessageContent {
  late String groupId;
  late String invitor;
  late List<String> invitees;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      invitor = map['o'];
      groupId = map['g'];
      invitees = Tools.convertDynamicList(map['ms']);
    } else {
      groupId = "";
      invitees = [];
      invitor = "";
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
    map['o'] = invitor;
    map['g'] = groupId;
    map['ms'] = invitees;
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    if (invitees.length == 1 && invitees[0] == invitor) {
      if (invitor == Imclient.currentUserId) {
        return '你加入了群聊';
      } else {
        UserInfo? userInfo =
            await Imclient.getUserInfo(invitor, groupId: groupId);
        if (userInfo != null) {
          return '${userInfo.getReadableName()} 加入了群聊';
        } else {
          return '$invitor 加入了群聊';
        }
      }
    }

    String formatMsg;
    if (invitor == Imclient.currentUserId) {
      formatMsg = '你 邀请';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(invitor, groupId: groupId);
      if (userInfo != null) {
        formatMsg = '${userInfo.getReadableName()} 邀请';
      } else {
        formatMsg = '$invitor 邀请';
      }
    }

    for (int i = 0; i < invitees.length; ++i) {
      String memberId = invitees[i];
      if (memberId == Imclient.currentUserId) {
        formatMsg = '$formatMsg 你';
      } else {
        UserInfo? userInfo =
            await Imclient.getUserInfo(memberId, groupId: groupId);
        if (userInfo != null) {
          formatMsg = '$formatMsg ${userInfo.getReadableName()}';
        } else {
          formatMsg = '$formatMsg $invitor';
        }
      }
    }

    formatMsg = '$formatMsg 加入了群组';
    return formatMsg;
  }

  @override
  MessageContentMeta get meta => addGroupMemberNotificationContentMeta;
}
