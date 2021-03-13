import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/message/notification/notification_message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/model/user_info.dart';

// ignore: non_constant_identifier_names
MessageContent GroupJoinTypeNotificationContentCreator() {
  return new GroupJoinTypeNotificationContent();
}

const groupJoinTypeNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_CHANGE_JOINTYPE,
    MessageFlag.PERSIST,
    GroupJoinTypeNotificationContentCreator);

class GroupJoinTypeNotificationContent extends NotificationMessageContent {
  String groupId;
  String operatorId;

  ///0 开放加入，1 运行群成员添加，2 仅管理员或群主添加
  String type;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    operatorId = map['o'];
    groupId = map['g'];
    type = map['n'];
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    Map<String, dynamic> map = new Map();
    map['o'] = operatorId;
    map['g'] = groupId;
    map['n'] = type;
    payload.binaryContent = new Uint8List.fromList(json.encode(map).codeUnits);
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String formatMsg;
    if (operatorId == await FlutterImclient.currentUserId) {
      formatMsg = '你';
    } else {
      UserInfo userInfo =
          await FlutterImclient.getUserInfo(operatorId, groupId: groupId);
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
          formatMsg = '$operatorId';
        }
      } else {
        formatMsg = '$operatorId';
      }
    }

    if (type == '0') {
      formatMsg = '$formatMsg 开放了加入群组权限';
    } else if (type == '1') {
      formatMsg = '$formatMsg 仅允许群成员邀请加群';
    } else {
      formatMsg = '$formatMsg 关闭了加入群组功能';
    }
    return formatMsg;
  }

  @override
  MessageContentMeta get meta => groupJoinTypeNotificationContentMeta;
}
