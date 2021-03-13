import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/message/notification/notification_message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/model/user_info.dart';

// ignore: non_constant_identifier_names
MessageContent QuitGroupNotificationContentCreator() {
  return new QuitGroupNotificationContent();
}

const quitGroupNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_QUIT_GROUP,
    MessageFlag.PERSIST,
    QuitGroupNotificationContentCreator);

class QuitGroupNotificationContent extends NotificationMessageContent {
  String groupId;
  String quitMember;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    quitMember = map['o'];
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
    map['o'] = quitMember;
    map['g'] = groupId;
    payload.binaryContent = new Uint8List.fromList(json.encode(map).codeUnits);
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    if (quitMember == await FlutterImclient.currentUserId) {
      return '你 退出了群组';
    } else {
      UserInfo userInfo =
          await FlutterImclient.getUserInfo(quitMember, groupId: groupId);
      if (userInfo != null) {
        if (userInfo.friendAlias != null && userInfo.friendAlias.isNotEmpty) {
          return '${userInfo.friendAlias} 退出了群组';
        } else if (userInfo.groupAlias != null &&
            userInfo.groupAlias.isNotEmpty) {
          return '${userInfo.groupAlias} 退出了群组';
        } else if (userInfo.displayName != null &&
            userInfo.displayName.isNotEmpty) {
          return '${userInfo.displayName} 退出了群组';
        } else {
          return '$quitMember 退出了群组';
        }
      } else {
        return '$quitMember 退出了群组';
      }
    }
  }

  @override
  MessageContentMeta get meta => quitGroupNotificationContentMeta;
}
