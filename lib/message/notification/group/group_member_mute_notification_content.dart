import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/message/notification/notification_message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/model/user_info.dart';

// ignore: non_constant_identifier_names
MessageContent GroupMemberMuteNotificationContentCreator() {
  return new GroupMemberMuteNotificationContent();
}

const groupMemberMuteNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_MUTE_MEMBER,
    MessageFlag.PERSIST,
    GroupMemberMuteNotificationContentCreator);

class GroupMemberMuteNotificationContent extends NotificationMessageContent {
  String groupId;
  String creator;
  //0 设置禁言名单，1 取消名单。
  String type;
  List<String> targetIds;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    creator = map['o'];
    groupId = map['g'];
    type = map['n'];
    targetIds = FlutterImclient.convertDynamicList(map['ms']);
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    Map<String, dynamic> map = new Map();
    map['o'] = creator;
    map['g'] = groupId;
    map['n'] = type;
    map['ms'] = targetIds;
    payload.binaryContent = new Uint8List.fromList(json.encode(map).codeUnits);
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String formatMsg;
    if (creator == await FlutterImclient.currentUserId) {
      formatMsg = '你';
    } else {
      UserInfo userInfo =
          await FlutterImclient.getUserInfo(creator, groupId: groupId);
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
          formatMsg = '$creator';
        }
      } else {
        formatMsg = '$creator';
      }
    }

    if (type == '1') {
      formatMsg = '$formatMsg 禁言了 ';
    } else {
      formatMsg = '$formatMsg 取消禁言了 ';
    }

    for (int i = 0; i < targetIds.length; ++i) {
      String memberId = targetIds[i];
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
            formatMsg = '$formatMsg $creator';
          }
        } else {
          formatMsg = '$formatMsg $creator';
        }
      }
    }

    return formatMsg;
  }

  @override
  MessageContentMeta get meta => groupMemberMuteNotificationContentMeta;
}
