import 'dart:convert';
import 'dart:typed_data';

import '../../imclient.dart';
import '../../model/conversation.dart';
import '../../model/message_payload.dart';
import '../../model/user_info.dart';
import '../message.dart';
import '../message_content.dart';
import 'notification_message_content.dart';


// ignore: non_constant_identifier_names
MessageContent RecallNotificationContentCreator() {
  return new RecallNotificationContent();
}

const recallNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_RECALL,
    MessageFlag.PERSIST,
    RecallNotificationContentCreator);

class RecallNotificationContent extends NotificationMessageContent {
  late int messageUid;
  late String operatorId;
  String? originalSender;
  int? originalContentType;
  String? originalSearchableContent;
  String? originalContent;
  String? originalExtra;
  int? originalMessageTimestamp;

  @override
  Future<void> decode(MessagePayload payload) async {
    super.decode(payload);
    if(payload.content != null) {
      operatorId = payload.content!;
    } else {
      operatorId = "";
    }
    if(payload.binaryContent != null) {
      messageUid = int.parse(utf8.decode(payload.binaryContent!));
    } else {
      messageUid = 0;
    }
    if (extra != null) {
      var map = json.decode(extra!);
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
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = operatorId;
    payload.binaryContent = Uint8List.fromList(utf8.encode(messageUid.toString()));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    UserInfo? userInfo;
    if (message.conversation.conversationType == ConversationType.Group) {
      userInfo = await Imclient.getUserInfo(operatorId,
          groupId: message.conversation.target);
    } else {
      userInfo = await Imclient.getUserInfo(operatorId);
    }
    String name;
    if (userInfo != null) {
      name = userInfo.getReadableName();
    } else {
      name = operatorId;
    }
    return '$name 撤回了一条消息';
  }
}
