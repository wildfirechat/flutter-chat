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
MessageContent GroupSetManagerNotificationContentCreator() {
  return GroupSetManagerNotificationContent();
}

const groupSetManagerNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_SET_MANAGER,
    MessageFlag.PERSIST,
    GroupSetManagerNotificationContentCreator);

class GroupSetManagerNotificationContent extends NotificationMessageContent {
  late String groupId;
  late String operatorId;

  /// 0 取消，1 设置。
  late String type;
  late List<String> memberIds;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      operatorId = map['o'];
      groupId = map['g'];
      type = map['n'];
      memberIds = Tools.convertDynamicList(map['ms'])!;
    } else {
      operatorId = "";
      groupId = "";
      type = "0";
      memberIds = [];
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
    map['o'] = operatorId;
    map['g'] = groupId;
    map['n'] = type;
    map['ms'] = memberIds;
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String formatMsg;
    if (operatorId == Imclient.currentUserId) {
      formatMsg = '你';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(operatorId, groupId: groupId);
      if (userInfo != null) {
        formatMsg = userInfo.getReadableName();
      } else {
        formatMsg = operatorId;
      }
    }

    if (type == '1') {
      formatMsg = '$formatMsg 设置 ';
    } else {
      formatMsg = '$formatMsg 取消 ';
    }

    for (int i = 0; i < memberIds.length; ++i) {
      String memberId = memberIds[i];
      if (memberId == Imclient.currentUserId) {
        formatMsg = '$formatMsg 你';
      } else {
        UserInfo? userInfo =
            await Imclient.getUserInfo(memberId, groupId: groupId);
        if (userInfo != null) {
          formatMsg = '$formatMsg ${userInfo.getReadableName()}';
        } else {
          formatMsg = '$formatMsg $operatorId';
        }
      }
    }

    if (type == '1') {
      formatMsg = '$formatMsg 为管理员';
    } else {
      formatMsg = '$formatMsg 管理员权限';
    }

    return formatMsg;
  }

  @override
  MessageContentMeta get meta => groupSetManagerNotificationContentMeta;
}
