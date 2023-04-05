import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';


// ignore: non_constant_identifier_names
MessageContent ChangeGroupNameNotificationContentCreator() {
  return new ChangeGroupNameNotificationContent();
}

const changeGroupNameNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_CHANGE_GROUP_NAME,
    MessageFlag.PERSIST,
    ChangeGroupNameNotificationContentCreator);

class ChangeGroupNameNotificationContent extends NotificationMessageContent {
  late String groupId;
  late String operateUser;
  late String name;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      operateUser = map['o'];
      groupId = map['g'];
      name = map['n'];
    } else {
      groupId = "";
      operateUser = "";
      name = "";
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
    map['n'] = name;
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    if (operateUser == await Imclient.currentUserId) {
      return '你 修改群名片为: $name';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(operateUser, groupId: groupId);
      if (userInfo != null) {
        return '${userInfo.getReadableName()} 修改群名片为: $name';
      } else {
        return '$operateUser 修改群名片为: $name';
      }
    }
  }

  @override
  MessageContentMeta get meta => changeGroupNameNotificationContentMeta;
}
