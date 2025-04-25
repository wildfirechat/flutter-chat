import 'dart:convert';
import 'dart:typed_data';

import '../../imclient.dart';
import '../../model/message_payload.dart';
import '../../model/user_info.dart';
import '../../tools.dart';
import '../message.dart';
import '../message_content.dart';
import 'notification_message_content.dart';


// ignore: non_constant_identifier_names
MessageContent CallAddParticipantsNotificationContentCreator() {
  return CallAddParticipantsNotificationContent();
}

const callAddParticipantsNotificationContentMeta = MessageContentMeta(
    VOIP_CONTENT_TYPE_ADD_PARTICIPANT,
    MessageFlag.PERSIST,
    CallAddParticipantsNotificationContentCreator);

class CallAddParticipantsNotificationContent extends NotificationMessageContent {
  late String callId;
  String? initiator;
  String? pin;
  List<String>? participants;
  //[{"userId":"xxxx","acceptTime":13123123123,"joinTime":13123123123,"videoMuted":false}]
  // List<Map<String, dynamic>>? existParticipants;
  List<dynamic>? existParticipants;
  bool audioOnly = false;
  bool autoAnswer = false;
  //指定对方clientId
  String? clientId;

  @override
  Future<void> decode(MessagePayload payload) async {
    super.decode(payload);
    callId = payload.content!;
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      initiator = map['initiator'];
      pin = map['pin'];
      participants = Tools.convertDynamicList(map['participants']);
      existParticipants = map['existParticipants'];
      if(map['audioOnly'] != null) {
        audioOnly = map['audioOnly'] == 1 ? true : false;
      }

      if(map['autoAnswer'] != null) {
        autoAnswer = map['autoAnswer'];
      }
      clientId = map['clientId'];
    }
  }

  @override
  MessageContentMeta get meta => callAddParticipantsNotificationContentMeta;

  @override
  Future<String> formatNotification(Message message) async {
    return digest(message);
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.content = callId;
    Map<String, dynamic> map = {};
    map['initiator'] = initiator;
    map['pin'] = pin;
    map['participants'] = participants;

    map['existParticipants'] = existParticipants;
    map['audioOnly'] = audioOnly;
    map['autoAnswer'] = autoAnswer;
    map['clientId'] = clientId;
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));

    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    String formatMsg = "";
    if(message.fromUser == Imclient.currentUserId) {
      formatMsg = "你";
    } else {
      UserInfo? fromUser = await Imclient.getUserInfo(message.fromUser, groupId: message.conversation.target);
      if(fromUser != null) {
        formatMsg = fromUser.getReadableName();
      }
    }

    formatMsg = '$formatMsg 邀请 ';

    for (int i = 0; i < participants!.length; ++i) {
      String memberId = participants![i];
      if (memberId == Imclient.currentUserId) {
        formatMsg = '$formatMsg 你';
      } else {
        UserInfo? userInfo =
        await Imclient.getUserInfo(memberId, groupId: message.fromUser);
        if (userInfo != null) {
          formatMsg = '$formatMsg ${userInfo.getReadableName()}';
        } else {
          formatMsg = '$formatMsg <$memberId>';
        }
      }
    }

    formatMsg = '$formatMsg 加入通话';

    return formatMsg;
  }
}
