import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/message/notification/notification_message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/model/user_info.dart';

// ignore: non_constant_identifier_names
MessageContent ModifyGroupMemberAliasNotificationContentCreator() {
  return new ModifyGroupMemberAliasNotificationContent();
}

const modifyGroupMemberAliasNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_MODIFY_GROUP_ALIAS,
    MessageFlag.PERSIST,
    ModifyGroupMemberAliasNotificationContentCreator);

class ModifyGroupMemberAliasNotificationContent
    extends NotificationMessageContent {
  String groupId;
  String operateUser;
  String alias;

  /// 如果群成员修改自己的群名片，memberId为空。如果群管理或者群主修改群成员的群名片，memberId为群成员Id
  String memberId;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    operateUser = map['o'];
    groupId = map['g'];
    alias = map['n'];
    memberId = map['m'];
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
    map['n'] = alias;
    if (memberId != null) {
      map['m'] = memberId;
    }
    payload.binaryContent = new Uint8List.fromList(json.encode(map).codeUnits);
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String formatMsg;
    if (operateUser == await FlutterImclient.currentUserId) {
      formatMsg = '你';
    } else {
      UserInfo userInfo =
          await FlutterImclient.getUserInfo(operateUser, groupId: groupId);
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

    formatMsg = '$formatMsg 修改';

    if (memberId == await FlutterImclient.currentUserId) {
      formatMsg = '$formatMsg 你';
    } else if (memberId == null || memberId.isEmpty) {
      formatMsg = '$formatMsg 自己';
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
          formatMsg = '$formatMsg $operateUser';
        }
      } else {
        formatMsg = '$formatMsg $operateUser';
      }
    }

    formatMsg = '$formatMsg 的群昵称为 $alias';

    return formatMsg;
  }

  @override
  MessageContentMeta get meta => modifyGroupMemberAliasNotificationContentMeta;
}
