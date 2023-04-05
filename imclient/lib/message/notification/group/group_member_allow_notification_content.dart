import 'dart:convert';
import 'dart:typed_data';

import 'package:imclient/tools.dart';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent GroupMemberAllowNotificationContentCreator() {
  return GroupMemberAllowNotificationContent();
}

const groupMemberAllowNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_ALLOW_MEMBER,
    MessageFlag.PERSIST,
    GroupMemberAllowNotificationContentCreator);

class GroupMemberAllowNotificationContent extends NotificationMessageContent {
  late String groupId;
  late String creator;
  //0 设置百名单，1 取消白名单。
  late String type;
  late List<String> targetIds;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      creator = map['o'];
      groupId = map['g'];
      type = map['n'];
      targetIds = Tools.convertDynamicList(map['ms'])!;
    } else {
      creator = "";
      groupId = "";
      type = "0";
      targetIds = [];
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
    map['ms'] = targetIds;
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String formatMsg;
    if (creator == await Imclient.currentUserId) {
      formatMsg = '你';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(creator, groupId: groupId);
      if (userInfo != null) {
        formatMsg = userInfo.getReadableName();
      } else {
        formatMsg = creator;
      }
    }

    if (type == '1') {
      formatMsg = '$formatMsg 允许了 ';
    } else {
      formatMsg = '$formatMsg 取消了 ';
    }

    for (int i = 0; i < targetIds.length; ++i) {
      String memberId = targetIds[i];
      if (memberId == await Imclient.currentUserId) {
        formatMsg = '$formatMsg 你';
      } else {
        UserInfo? userInfo =
            await Imclient.getUserInfo(memberId, groupId: groupId);
        if (userInfo != null) {
          formatMsg = '$formatMsg ${userInfo.getReadableName()}';
        } else {
          formatMsg = '$formatMsg $creator';
        }
      }
    }

    formatMsg = '$formatMsg 群组禁言时的发言权限';

    return formatMsg;
  }

  @override
  MessageContentMeta get meta => groupMemberAllowNotificationContentMeta;
}
