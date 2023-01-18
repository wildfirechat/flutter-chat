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
  return new GroupSetManagerNotificationContent();
}

const groupSetManagerNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_SET_MANAGER,
    MessageFlag.PERSIST,
    GroupSetManagerNotificationContentCreator);

class GroupSetManagerNotificationContent extends NotificationMessageContent {
  String groupId;
  String operatorId;

  /// 0 取消，1 设置。
  String type;
  List<String> memberIds;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    operatorId = map['o'];
    groupId = map['g'];
    type = map['n'];
    memberIds = Tools.convertDynamicList(map['ms']);
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();
    Map<String, dynamic> map = new Map();
    map['o'] = operatorId;
    map['g'] = groupId;
    map['n'] = type;
    map['ms'] = memberIds;
    payload.binaryContent = new Uint8List.fromList(json.encode(map).codeUnits);
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String formatMsg;
    if (operatorId == await Imclient.currentUserId) {
      formatMsg = '你';
    } else {
      UserInfo userInfo =
          await Imclient.getUserInfo(operatorId, groupId: groupId);
      if (userInfo != null) {
        if (userInfo.friendAlias != null && userInfo.friendAlias.isNotEmpty) {
          formatMsg = '${userInfo.friendAlias}';
        } else if (userInfo.groupAlias != null &&
            userInfo.groupAlias.isNotEmpty) {
          formatMsg = '${userInfo.groupAlias}';
        } else if (userInfo.displayName != null &&
            userInfo.displayName.isNotEmpty) {
          formatMsg = '${userInfo.displayName}';
        } else {
          formatMsg = '$operatorId';
        }
      } else {
        formatMsg = '$operatorId';
      }
    }

    if (type == '1') {
      formatMsg = '$formatMsg 设置 ';
    } else {
      formatMsg = '$formatMsg 取消 ';
    }

    for (int i = 0; i < memberIds.length; ++i) {
      String memberId = memberIds[i];
      if (memberId == await Imclient.currentUserId) {
        formatMsg = '$formatMsg 你';
      } else {
        UserInfo userInfo =
            await Imclient.getUserInfo(memberId, groupId: groupId);
        if (userInfo != null) {
          if (userInfo.friendAlias != null && userInfo.friendAlias.isNotEmpty) {
            formatMsg = '$formatMsg ${userInfo.friendAlias}';
          } else if (userInfo.groupAlias != null &&
              userInfo.groupAlias.isNotEmpty) {
            formatMsg = '$formatMsg ${userInfo.groupAlias}';
          } else if (userInfo.displayName != null &&
              userInfo.displayName.isNotEmpty) {
            formatMsg = '$formatMsg ${userInfo.displayName}';
          } else {
            formatMsg = '$formatMsg $operatorId';
          }
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
