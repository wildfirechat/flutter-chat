import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent ModifyGroupExtraNotificationContentCreator() {
  return ModifyGroupExtraNotificationContent();
}

const modifyGroupExtraNotificationContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_MODIFY_GROUP_EXTRA,
  MessageFlag.PERSIST,
  ModifyGroupExtraNotificationContentCreator,
);

/// 修改群组Extra通知消息
///
/// 群扩展信息被修改时的通知
/// 消息类型: 122
class ModifyGroupExtraNotificationContent
    extends NotificationMessageContent {
  late String groupId;
  late String operateUser;
  String groupExtra = '';

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload.binaryContent != null) {
      Map<dynamic, dynamic> map =
          json.decode(utf8.decode(payload.binaryContent!));
      operateUser = map['o'] ?? '';
      groupId = map['g'] ?? '';
    }
    groupExtra = payload.content ?? '';
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = groupExtra;
    Map<String, dynamic> map = {
      'o': operateUser,
      'g': groupId,
    };
    payload.binaryContent =
        Uint8List.fromList(utf8.encode(json.encode(map)));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    String formatMsg;
    if (operateUser == Imclient.currentUserId) {
      formatMsg = '你';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(operateUser, groupId: groupId);
      formatMsg = userInfo?.getReadableName() ?? operateUser;
    }
    formatMsg = '$formatMsg 修改了群扩展信息';

    return formatMsg;
  }

  @override
  MessageContentMeta get meta => modifyGroupExtraNotificationContentMeta;
}
