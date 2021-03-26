import 'dart:convert';

import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/message/notification/notification_message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/model/user_info.dart';

// ignore: non_constant_identifier_names
MessageContent GroupPrivateChatNotificationContentCreator() {
  return new GroupPrivateChatNotificationContent();
}

const groupPrivateChatNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_CHANGE_PRIVATECHAT,
    MessageFlag.PERSIST,
    GroupPrivateChatNotificationContentCreator);

class GroupPrivateChatNotificationContent extends NotificationMessageContent {
  String groupId;
  String invitor;

  ///0 允许私聊，1 不允许私聊。
  String type;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    invitor = map['o'];
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
    map['o'] = invitor;
    map['g'] = groupId;
    map['n'] = type;
    payload.binaryContent = utf8.encode(json.encode(map));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String str;
    if (type == '0') {
      str = '开启了成员私聊';
    } else {
      str = '关闭了成员私聊';
    }

    if (invitor == await FlutterImclient.currentUserId) {
      return '你 $str';
    } else {
      UserInfo userInfo =
          await FlutterImclient.getUserInfo(invitor, groupId: groupId);
      if (userInfo != null) {
        if (userInfo.friendAlias != null && userInfo.friendAlias.isNotEmpty) {
          return '${userInfo.friendAlias} $str';
        } else if (userInfo.groupAlias != null &&
            userInfo.groupAlias.isNotEmpty) {
          return '${userInfo.groupAlias} $str';
        } else if (userInfo.displayName != null &&
            userInfo.displayName.isNotEmpty) {
          return '${userInfo.displayName} $str';
        } else {
          return '$invitor $str';
        }
      } else {
        return '$invitor $str';
      }
    }
  }

  @override
  MessageContentMeta get meta => groupPrivateChatNotificationContentMeta;
}
