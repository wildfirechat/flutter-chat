import 'dart:convert';
import 'dart:typed_data';

import '../../../imclient.dart';
import '../../../model/message_payload.dart';
import '../../../model/user_info.dart';
import '../../message.dart';
import '../../message_content.dart';
import '../notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent TransferGroupOwnerNotificationContentCreator() {
  return TransferGroupOwnerNotificationContent();
}

const transferGroupOwnerNotificationContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_ADD_GROUP_MEMBER,
    MessageFlag.PERSIST,
    TransferGroupOwnerNotificationContentCreator);

class TransferGroupOwnerNotificationContent extends NotificationMessageContent {
  late String groupId;
  late String operateUser;
  late String owner;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      operateUser = map['o'];
      groupId = map['g'];
      owner = map['m'];
    } else {
      operateUser = "";
      groupId = "";
      owner = "";
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
    map['m'] = owner;
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

    formatMsg = '$formatMsg 把群组转让给了';

    if (owner == await Imclient.currentUserId) {
      formatMsg = '$formatMsg 你';
    } else {
      UserInfo? userInfo =
          await Imclient.getUserInfo(owner, groupId: groupId);
      if (userInfo != null) {
        formatMsg = '$formatMsg ${userInfo.getReadableName()}';
      } else {
        formatMsg = '$formatMsg $operateUser';
      }
    }

    return formatMsg;
  }

  @override
  MessageContentMeta get meta => transferGroupOwnerNotificationContentMeta;
}
