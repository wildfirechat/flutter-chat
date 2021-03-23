import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/message/notification/notification_message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/model/user_info.dart';

// ignore: non_constant_identifier_names
MessageContent DismissGroupNotificationContentCreator() {
  return new DismissGroupNotificationContent();
}

const dismissGroupNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_DISMISS_GROUP,
    MessageFlag.PERSIST,
    DismissGroupNotificationContentCreator);

class DismissGroupNotificationContent extends NotificationMessageContent {
  String groupId;
  String operateUser;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    operateUser = map['o'];
    groupId = map['g'];
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
    payload.binaryContent = new Uint8List.fromList(json.encode(map).codeUnits);
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    if (operateUser == await FlutterImclient.currentUserId) {
      return '你 销毁了群组';
    } else {
      UserInfo userInfo =
          await FlutterImclient.getUserInfo(operateUser, groupId: groupId);
      if (userInfo != null) {
        if (userInfo.friendAlias != null && userInfo.friendAlias.isNotEmpty) {
          return '${userInfo.friendAlias} 销毁了群组';
        } else if (userInfo.groupAlias != null &&
            userInfo.groupAlias.isNotEmpty) {
          return '${userInfo.groupAlias} 销毁了群组';
        } else if (userInfo.displayName != null &&
            userInfo.displayName.isNotEmpty) {
          return '${userInfo.displayName} 销毁了群组';
        } else {
          return '$operateUser 销毁了群组';
        }
      } else {
        return '$operateUser 销毁了群组';
      }
    }
  }

  @override
  MessageContentMeta get meta => dismissGroupNotificationContentMeta;
}
