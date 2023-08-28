import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent QuitGroupNotificationContentCreator() {
  return QuitGroupNotificationContent();
}

const quitGroupNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_QUIT_GROUP,
    MessageFlag.PERSIST,
    QuitGroupNotificationContentCreator);

class QuitGroupNotificationContent extends NotificationMessageContent {
  late String groupId;
  late String quitMember;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      quitMember = map['o'];
      groupId = map['g'];
    } else {
      groupId = "";
      quitMember = "";
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
    map['o'] = quitMember;
    map['g'] = groupId;
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));
    return payload;
  }

  @override
  Future<String> formatNotification(Message message) async {
    if (quitMember == Imclient.currentUserId) {
      return '你 退出了群组';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(quitMember, groupId: groupId);
      if (userInfo != null) {
        return '${userInfo.getReadableName()} 退出了群组';
      } else {
        return '$quitMember 退出了群组';
      }
    }
  }

  @override
  MessageContentMeta get meta => quitGroupNotificationContentMeta;
}
