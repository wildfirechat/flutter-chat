import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent DismissGroupNotificationContentCreator() {
  return DismissGroupNotificationContent();
}

const dismissGroupNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_DISMISS_GROUP,
    MessageFlag.PERSIST,
    DismissGroupNotificationContentCreator);

class DismissGroupNotificationContent extends NotificationMessageContent {
  late String groupId;
  late String operateUser;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      operateUser = map['o'];
      groupId = map['g'];
    } else {
      operateUser = "";
      groupId = "";
    }
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    Map<String, dynamic> map = {};
    map['o'] = operateUser;
    map['g'] = groupId;
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    if (operateUser == Imclient.currentUserId) {
      return '你 销毁了群组';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(operateUser, groupId: groupId);
      if (userInfo != null) {
        return '${userInfo.getReadableName()} 销毁了群组';
      } else {
        return '$operateUser 销毁了群组';
      }
    }
  }

  @override
  MessageContentMeta get meta => dismissGroupNotificationContentMeta;
}
