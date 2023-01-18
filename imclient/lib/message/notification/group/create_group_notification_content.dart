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
  return new CreateGroupNotificationContent();
}

const createGroupNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_CREATE_GROUP,
    MessageFlag.PERSIST,
    CreateGroupNotificationContentCreator);

class CreateGroupNotificationContent extends NotificationMessageContent {
  String groupId;
  String creator;
  String groupName;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    creator = map['o'];
    groupId = map['g'];
    groupName = map['n'];
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
    map['n'] = groupName;
    payload.binaryContent = new Uint8List.fromList(json.encode(map).codeUnits);
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    if (creator == await Imclient.currentUserId) {
      return '你 创建了群组';
    } else {
      UserInfo userInfo =
          await Imclient.getUserInfo(creator, groupId: groupId);
      if (userInfo != null) {
        if (userInfo.friendAlias != null && userInfo.friendAlias.isNotEmpty) {
          return '${userInfo.friendAlias} 创建了群组';
        } else if (userInfo.groupAlias != null &&
            userInfo.groupAlias.isNotEmpty) {
          return '${userInfo.groupAlias} 创建了群组';
        } else if (userInfo.displayName != null &&
            userInfo.displayName.isNotEmpty) {
          return '${userInfo.displayName} 创建了群组';
        } else {
          return '$creator 创建了群组';
        }
      } else {
        return '$creator 创建了群组';
      }
    }
  }

  @override
  MessageContentMeta get meta => createGroupNotificationContentMeta;
}
