import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/message/notification/notification_message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/model/user_info.dart';

// ignore: non_constant_identifier_names
MessageContent GroupMuteNotificationContentCreator() {
  return new GroupMuteNotificationContent();
}

const groupMuteNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_CHANGE_MUTE,
    MessageFlag.PERSIST,
    GroupMuteNotificationContentCreator);

class GroupMuteNotificationContent extends NotificationMessageContent {
  String groupId;
  String creator;
  //0 设置群禁言，1 取消群禁言。
  String type;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    creator = map['o'];
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
    map['o'] = creator;
    map['g'] = groupId;
    map['n'] = type;
    payload.binaryContent = new Uint8List.fromList(json.encode(map).codeUnits);
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String str;
    if (type == '1') {
      str = '开启了全员禁言';
    } else {
      str = '关闭了全员禁言';
    }

    if (creator == await FlutterImclient.currentUserId) {
      return '你 $str';
    } else {
      UserInfo userInfo =
          await FlutterImclient.getUserInfo(creator, groupId: groupId);
      if (userInfo != null) {
        if (userInfo.friendAlias != null && userInfo.friendAlias.isNotEmpty) {
          return '${userInfo.friendAlias} $str';
        } else if (userInfo.groupAlias != null) {
          return '${userInfo.groupAlias} $str';
        } else if (userInfo.displayName != null &&
            userInfo.displayName.isNotEmpty) {
          return '${userInfo.displayName} $str';
        } else {
          return '$creator $str';
        }
      } else {
        return '$creator $str';
      }
    }
  }

  @override
  MessageContentMeta get meta => groupMuteNotificationContentMeta;
}
