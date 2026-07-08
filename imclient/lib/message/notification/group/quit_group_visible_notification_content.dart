import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent QuitGroupVisibleNotificationContentCreator() {
  return QuitGroupVisibleNotificationContent();
}

const quitGroupVisibleNotificationContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_QUIT_GROUP_VISIBLE,
  MessageFlag.PERSIST,
  QuitGroupVisibleNotificationContentCreator,
);

/// 退群的可见通知消息
///
/// 群成员退出后，对所有成员可见的通知
/// 消息类型: 121
class QuitGroupVisibleNotificationContent
    extends NotificationMessageContent {
  late String groupId;
  late String operateUser;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload.binaryContent != null) {
      Map<dynamic, dynamic> map =
          json.decode(utf8.decode(payload.binaryContent!));
      operateUser = map['o'];
      groupId = map['g'];
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
    formatMsg = '$formatMsg 已退出群聊';

    return formatMsg;
  }

  @override
  MessageContentMeta get meta => quitGroupVisibleNotificationContentMeta;
}
