import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent ModifyGroupMemberAliasNotificationContentCreator() {
  return ModifyGroupMemberAliasNotificationContent();
}

const modifyGroupMemberAliasNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_MODIFY_GROUP_ALIAS,
    MessageFlag.PERSIST,
    ModifyGroupMemberAliasNotificationContentCreator);

class ModifyGroupMemberAliasNotificationContent
    extends NotificationMessageContent {
  late String groupId;
  late String operateUser;
  late String alias;

  /// 如果群成员修改自己的群名片，memberId为空。如果群管理或者群主修改群成员的群名片，memberId为群成员Id
  String? memberId;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      operateUser = map['o'];
      groupId = map['g'];
      alias = map['n'];
      memberId = map['m'];
    } else {
      operateUser = "";
      groupId = "";
      alias = "";
      memberId = "";
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
    map['n'] = alias;
    if (memberId != null) {
      map['m'] = memberId;
    }
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String formatMsg;
    if (operateUser == await Imclient.currentUserId) {
      formatMsg = '你';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(operateUser, groupId: groupId);
      if (userInfo != null) {
        formatMsg = userInfo.getReadableName();
      } else {
        formatMsg = operateUser;
      }
    }

    formatMsg = '$formatMsg 修改';

    if (memberId == await Imclient.currentUserId) {
      formatMsg = '$formatMsg 你';
    } else if (memberId == null || memberId!.isEmpty) {
      formatMsg = '$formatMsg 自己';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(memberId!, groupId: groupId);
      if (userInfo != null) {
        formatMsg = '$formatMsg ${userInfo.getReadableName()}';
      } else {
        formatMsg = '$formatMsg $operateUser';
      }
    }

    formatMsg = '$formatMsg 的群昵称为 $alias';

    return formatMsg;
  }

  @override
  MessageContentMeta get meta => modifyGroupMemberAliasNotificationContentMeta;
}
