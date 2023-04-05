import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent GroupMuteNotificationContentCreator() {
  return GroupMuteNotificationContent();
}

const groupMuteNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_CHANGE_MUTE,
    MessageFlag.PERSIST,
    GroupMuteNotificationContentCreator);

class GroupMuteNotificationContent extends NotificationMessageContent {
  late String groupId;
  late String creator;
  //0 设置群禁言，1 取消群禁言。
  late String type;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      creator = map['o'];
      groupId = map['g'];
      type = map['n'];
    } else {
      creator = "";
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
    map['o'] = creator;
    map['g'] = groupId;
    map['n'] = type;
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String str;
    if (type == '1') {
      str = '开启了全员禁言';
    } else {
      str = '关闭了全员禁言';
    }

    if (creator == await Imclient.currentUserId) {
      return '你 $str';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(creator, groupId: groupId);
      if (userInfo != null) {
        return '${userInfo.getReadableName()} $str';
      } else {
        return '$creator $str';
      }
    }
  }

  @override
  MessageContentMeta get meta => groupMuteNotificationContentMeta;
}
