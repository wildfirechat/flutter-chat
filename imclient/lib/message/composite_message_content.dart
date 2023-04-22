import 'dart:convert';
import 'dart:typed_data';

import '../imclient.dart';
import '../model/conversation.dart';
import '../model/message_payload.dart';
import 'media_message_content.dart';
import 'message.dart';
import 'message_content.dart';


// ignore: non_constant_identifier_names
MessageContent CompositeMessageContentCreator() {
  return CompositeMessageContent();
}

const compositeContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_COMPOSITE_MESSAGE,
    MessageFlag.PERSIST_AND_COUNT,
    CompositeMessageContentCreator);

class CompositeMessageContent extends MediaMessageContent {
  late String title;
  late List<Message> messages;

  @override
  MessageContentMeta get meta => compositeContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.content != null) {
      title = payload.content!;
    } else {
      title = "";
    }
    messages = [];
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      List<dynamic> ms = map['ms'];
      for (int i = 0; i < ms.length; ++i) {
        Map map = ms[i];
        Message msg = Message();
        msg.messageUid = map['uid'];
        msg.conversation = Conversation();
        msg.conversation.conversationType =
        ConversationType.values[map['type']];
        msg.conversation.target = map['target'];
        if(map['line'] != null) {
          msg.conversation.line = map['line'];
        } else {
          msg.conversation.line = 0;
        }

        msg.fromUser = map['from'];
        if(map['tos'] != null && map['tos'] is List<dynamic>) {
          msg.toUsers = map['tos'].cast<String>();
        }
        msg.direction = MessageDirection.MessageDirection_Send;
        if (map['direction'] != null) {
          msg.direction = MessageDirection.values[map['direction']];
        }
        if (map['status'] != null) {
          msg.status = MessageStatus.values[map['status']];
        }
        msg.serverTime = map['serverTime'];

        MessagePayload payload = MessagePayload();
        payload.contentType = map['ctype'];
        payload.searchableContent = map['csc'];
        payload.pushContent = map['cpc'];
        payload.pushData = map['cpd'];
        payload.content = map['cc'];
        if (map['cbc'] != null) {
          payload.binaryContent = const Base64Decoder().convert(map['cbc']);
        }
        payload.mentionedType = map['cmt']??0;
        if(map['cmts'] != null) {
          payload.mentionedTargets = map['cmts'].cast<String>();
        }
        payload.extra = map['ce'];
        if (map['mt'] != null) {
          payload.mediaType = MediaType.values[map['mt']];
        }
        payload.remoteMediaUrl = map['mru'];

        msg.content = Imclient.decodeMessageContent(payload);
        messages.add(msg);
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();

    payload.content = title;
    List<Map> ms = [];
    for (int i = 0; i < messages.length; ++i) {
      Message msg = messages.elementAt(i);
      Map map = {};
      if (msg.messageUid != null && msg.messageUid! > 0) {
        map['uid'] = msg.messageUid;
      }
      map['type'] = msg.conversation.conversationType.index;
      map['target'] = msg.conversation.target;
      map['line'] = msg.conversation.line;
      map['from'] = msg.fromUser;
      if (msg.toUsers != null && msg.toUsers!.isNotEmpty) {
        map['tos'] = msg.toUsers;
      }
      map['direction'] = msg.direction.index;
      map['status'] = msg.status.index;
      map['serverTime'] = msg.serverTime;

      MessagePayload payload = msg.content.encode();
      map['ctype'] = payload.contentType;
      map['csc'] = payload.searchableContent;
      map['cpc'] = payload.pushContent;
      map['cpd'] = payload.pushData;
      map['cc'] = payload.content;
      if (payload.binaryContent != null) {
        map['cbc'] = const Base64Encoder().convert(payload.binaryContent!);
      }
      map['cmt'] = payload.mentionedType;
      if (payload.mentionedTargets != null &&
          payload.mentionedTargets!.isNotEmpty) {
        map['cmts'] = payload.mentionedTargets;
      }
      map['ce'] = payload.extra;
      map['mt'] = payload.mediaType.index;
      if (payload.remoteMediaUrl != null) {
        map['mru'] = payload.remoteMediaUrl;
      }
      ms.add(map);
    }

    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode({'ms': ms})));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    if (title != null && title.isNotEmpty) {
      return '[聊天]:$title';
    }
    return '[聊天]';
  }
}
