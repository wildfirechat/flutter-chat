import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent GroupPrivateChatNotificationContentCreator() {
  return GroupPrivateChatNotificationContent();
}

const groupPrivateChatNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_CHANGE_PRIVATECHAT,
    MessageFlag.PERSIST,
    GroupPrivateChatNotificationContentCreator);

class GroupPrivateChatNotificationContent extends NotificationMessageContent {
  late String groupId;
  late String invitor;

  ///0 允许私聊，1 不允许私聊。
  late String type;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      invitor = map['o'];
      groupId = map['g'];
      type = map['n'];
    } else {
      invitor = "";
      groupId = "";
      type = "0";
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
    map['o'] = invitor;
    map['g'] = groupId;
    map['n'] = type;
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String str;
    if (type == '0') {
      str = '开启了成员私聊';
    } else {
      str = '关闭了成员私聊';
    }

    if (invitor == await Imclient.currentUserId) {
      return '你 $str';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(invitor, groupId: groupId);
      if (userInfo != null) {
        return '${userInfo.getReadableName()} $str';
      } else {
        return '$invitor $str';
      }
    }
  }

  @override
  MessageContentMeta get meta => groupPrivateChatNotificationContentMeta;
}
