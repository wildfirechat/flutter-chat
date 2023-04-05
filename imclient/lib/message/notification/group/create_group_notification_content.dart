import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent CreateGroupNotificationContentCreator() {
  return CreateGroupNotificationContent();
}

const createGroupNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_CREATE_GROUP,
    MessageFlag.PERSIST,
    CreateGroupNotificationContentCreator);

class CreateGroupNotificationContent extends NotificationMessageContent {
  late String groupId;
  late String creator;
  late String groupName;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      creator = map['o'];
      groupId = map['g'];
      groupName = map['n'];
    } else {
      creator = "";
      groupId = "";
      groupName = "";
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
    map['o'] = creator;
    map['g'] = groupId;
    map['n'] = groupName;
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    if (creator == await Imclient.currentUserId) {
      return '你 创建了群组';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(creator, groupId: groupId);
      if (userInfo != null) {
        return '${userInfo.getReadableName()} 创建了群组';
      } else {
        return '$creator 创建了群组';
      }
    }
  }

  @override
  MessageContentMeta get meta => createGroupNotificationContentMeta;
}
