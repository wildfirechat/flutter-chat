import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent GroupJoinTypeNotificationContentCreator() {
  return GroupJoinTypeNotificationContent();
}

const groupJoinTypeNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_CHANGE_JOINTYPE,
    MessageFlag.PERSIST,
    GroupJoinTypeNotificationContentCreator);

class GroupJoinTypeNotificationContent extends NotificationMessageContent {
  late String groupId;
  late String operatorId;

  ///0 开放加入，1 运行群成员添加，2 仅管理员或群主添加
  late String type;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      operatorId = map['o'];
      groupId = map['g'];
      type = map['n'];
    } else {
      operatorId = "";
      groupId = "";
      type = "";
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

    if (type == '0') {
      formatMsg = '$formatMsg 开放了加入群组权限';
    } else if (type == '1') {
      formatMsg = '$formatMsg 仅允许群成员邀请加群';
    } else {
      formatMsg = '$formatMsg 关闭了加入群组功能';
    }
    return formatMsg;
  }

  @override
  MessageContentMeta get meta => groupJoinTypeNotificationContentMeta;
}
