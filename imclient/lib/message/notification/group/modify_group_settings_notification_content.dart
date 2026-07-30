import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent ModifyGroupSettingsNotificationContentCreator() {
  return ModifyGroupSettingsNotificationContent();
}

const modifyGroupSettingsNotificationContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_MODIFY_GROUP_SETTINGS,
  MessageFlag.PERSIST,
  ModifyGroupSettingsNotificationContentCreator,
);

/// 修改群组设置通知消息
///
/// 群设置被修改时的通知（权限、加入方式等）
/// 消息类型: 124
class ModifyGroupSettingsNotificationContent
    extends NotificationMessageContent {
  late String groupId;
  late String operateUser;
  late Map<String, String> settings;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload.binaryContent != null) {
      Map<dynamic, dynamic> map =
          json.decode(utf8.decode(payload.binaryContent!));
      operateUser = map['o'] ?? '';
      groupId = map['g'] ?? '';
      settings = {};
      Map<dynamic, dynamic>? s = map['s'];
      if (s != null) {
        s.forEach((k, v) {
          settings[k.toString()] = v.toString();
        });
      }
    } else {
      operateUser = '';
      groupId = '';
      settings = {};
    }
  }

  @override
  Future<String> digest(Message message) async {
    return formatNotification(message);
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    Map<String, dynamic> map = {
      'o': operateUser,
      'g': groupId,
      's': settings,
    };
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));
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
    formatMsg = '$formatMsg 修改了群设置';

    return formatMsg;
  }

  @override
  MessageContentMeta get meta => modifyGroupSettingsNotificationContentMeta;
}
