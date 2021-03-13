import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/message/notification/notification_message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/model/user_info.dart';

// ignore: non_constant_identifier_names
MessageContent AddGroupMemberNotificationContentCreator() {
  return new AddGroupMemberNotificationContent();
}

const addGroupMemberNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_ADD_GROUP_MEMBER,
    MessageFlag.PERSIST,
    AddGroupMemberNotificationContentCreator);

class AddGroupMemberNotificationContent extends NotificationMessageContent {
  String groupId;
  String invitor;
  List<String> invitees;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    invitor = map['o'];
    groupId = map['g'];
    invitees = FlutterImclient.convertDynamicList(map['ms']);
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    Map<String, dynamic> map = new Map();
    map['o'] = invitor;
    map['g'] = groupId;
    map['ms'] = invitees;
    payload.binaryContent = new Uint8List.fromList(json.encode(map).codeUnits);
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    if (invitees.length == 1 && invitees[0] == invitor) {
      if (invitor == await FlutterImclient.currentUserId) {
        return '你加入了群聊';
      } else {
        UserInfo userInfo =
            await FlutterImclient.getUserInfo(invitor, groupId: groupId);
        if (userInfo != null) {
          if (userInfo.friendAlias != null && userInfo.friendAlias.isNotEmpty) {
            return '${userInfo.friendAlias} 加入了群聊';
          } else if (userInfo.groupAlias != null &&
              userInfo.groupAlias.isNotEmpty) {
            return '${userInfo.groupAlias} 加入了群聊';
          } else if (userInfo.displayName != null &&
              userInfo.displayName.isNotEmpty) {
            return '${userInfo.displayName} 加入了群聊';
          } else {
            return '$invitor 加入了群聊';
          }
        } else {
          return '$invitor 加入了群聊';
        }
      }
    }
    String formatMsg;
    if (invitor == await FlutterImclient.currentUserId) {
      formatMsg = '你 邀请';
    } else {
      UserInfo userInfo =
          await FlutterImclient.getUserInfo(invitor, groupId: groupId);
      if (userInfo != null) {
        if (userInfo.friendAlias != null && userInfo.friendAlias.isNotEmpty) {
          formatMsg = '${userInfo.friendAlias} 邀请';
        } else if (userInfo.groupAlias != null &&
            userInfo.groupAlias.isNotEmpty) {
          formatMsg = '${userInfo.groupAlias} 邀请';
        } else if (userInfo.displayName != null &&
            userInfo.displayName.isNotEmpty) {
          formatMsg = '${userInfo.displayName} 邀请';
        } else {
          formatMsg = '$invitor 邀请';
        }
      } else {
        formatMsg = '$invitor 邀请';
      }
    }

    for (int i = 0; i < invitees.length; ++i) {
      String memberId = invitees[i];
      if (memberId == await FlutterImclient.currentUserId) {
        formatMsg = '$formatMsg 你';
      } else {
        UserInfo userInfo =
            await FlutterImclient.getUserInfo(memberId, groupId: groupId);
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
            formatMsg = '$formatMsg $invitor';
          }
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
