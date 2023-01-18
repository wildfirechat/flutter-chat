import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

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
    if (quitMember == await Imclient.currentUserId) {
      return '你 退出了群组';
    } else {
      UserInfo userInfo =
          await Imclient.getUserInfo(quitMember, groupId: groupId);
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
