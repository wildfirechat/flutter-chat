import 'dart:convert';

import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/message/notification/notification_message_content.dart';
import 'package:flutter_imclient/model/conversation.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/model/user_info.dart';

// ignore: non_constant_identifier_names
MessageContent RecallNotificationContentCreator() {
  return new RecallNotificationContent();
}

const recallNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_RECALL,
    MessageFlag.PERSIST,
    RecallNotificationContentCreator);

class RecallNotificationContent extends NotificationMessageContent {
  int messageUid;
  String operatorId;
  String originalSender;
  int originalContentType;
  String originalSearchableContent;
  String originalContent;
  String originalExtra;
  int originalMessageTimestamp;

  @override
  Future<void> decode(MessagePayload payload) async {
    super.decode(payload);
    operatorId = payload.content;
    messageUid = int.parse(utf8.decode(payload.binaryContent));
    if (extra != null) {
      var map = json.decode(extra);
      originalSender = map['s'];
      originalContentType = map['t'];
      originalSearchableContent = map['sc'];
      originalContent = map['c'];
      originalExtra = map['e'];
      originalMessageTimestamp = map['ts'];
    }
  }

  @override
  MessageContentMeta get meta => recallNotificationContentMeta;

  @override
  Future<String> formatNotification(Message message) async {
    return 'recall';
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    payload.content = operatorId;
    payload.binaryContent = utf8.encode(messageUid.toString());
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    UserInfo userInfo;
    if (message.conversation != null &&
        message.conversation.conversationType == ConversationType.Group) {
      userInfo = await FlutterImclient.getUserInfo(operatorId,
          groupId: message.conversation.target);
    } else {
      userInfo = await FlutterImclient.getUserInfo(operatorId);
    }
    String name;
    if (userInfo != null) {
      if (userInfo.friendAlias != null && userInfo.friendAlias.isNotEmpty) {
        name = userInfo.friendAlias;
      } else if (userInfo.groupAlias != null &&
          userInfo.groupAlias.isNotEmpty) {
        name = userInfo.groupAlias;
      } else {
        name = userInfo.displayName;
      }
    } else {
      name = operatorId;
    }
    return '$name 撤回了一条消息';
  }
}
