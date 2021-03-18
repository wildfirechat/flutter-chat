import 'dart:convert';

import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/message/media_message_content.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/model/conversation.dart';
import 'package:flutter_imclient/model/message_payload.dart';

// ignore: non_constant_identifier_names
MessageContent CompositeMessageContentCreator() {
  return new CompositeMessageContent();
}

const compositeContentMeta = MessageContentMeta(
    MESSAGE_CONTENT_TYPE_COMPOSITE_MESSAGE,
    MessageFlag.PERSIST_AND_COUNT,
    CompositeMessageContentCreator);

class CompositeMessageContent extends MediaMessageContent {
  String title;
  List<Message> messages;

  @override
  MessageContentMeta get meta => compositeContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    title = payload.content;
    messages = new List();
    Map<dynamic, dynamic> map = json.decode(utf8.decode(payload.binaryContent));
    List<dynamic> ms = map['ms'];
    for (int i = 0; i < ms.length; ++i) {
      Map map = ms[i];
      Message msg = new Message();
      msg.messageUid = map['uid'];
      msg.conversation = new Conversation();
      msg.conversation.conversationType = ConversationType.values[map['type']];
      msg.conversation.target = map['target'];
      msg.conversation.line = map['line'];

      msg.fromUser = map['from'];
      msg.toUsers = map['tos'];
      msg.direction = MessageDirection.MessageDirection_Send;
      if(map['direction'] != null)
        msg.direction = MessageDirection.values[map['direction']];
      msg.status = MessageStatus.values[map['status']];
      msg.serverTime = map['serverTime'];

      MessagePayload payload = new MessagePayload();
      payload.contentType = map['ctype'];
      payload.searchableContent = map['csc'];
      payload.pushContent = map['cpc'];
      payload.pushData = map['cpd'];
      payload.content = map['cc'];
      if (map['cbc'] != null) {
        payload.binaryContent = Base64Decoder().convert(map['cbc']);
      }
      payload.mentionedType = map['cmt'];
      payload.mentionedTargets = map['cmts'];
      payload.extra = map['ce'];
      payload.mediaType = MediaType.values[map['mt']];
      payload.remoteMediaUrl = map['mru'];

      msg.content = FlutterImclient.decodeMessageContent(payload);
      messages.add(msg);
    }
  }

  @override
  Future<MessagePayload> encode() async {
    MessagePayload payload = await super.encode();

    payload.content = title;
    List<Map> ms = new List();
    for (int i = 0; i < messages.length; ++i) {
      Message msg = messages.elementAt(i);
      Map map = Map();
      if (msg.messageUid > 0) {
        map['uid'] = msg.messageUid;
      }
      map['type'] = msg.conversation.conversationType.index;
      map['target'] = msg.conversation.target;
      map['line'] = msg.conversation.line;
      map['from'] = msg.fromUser;
      if (msg.toUsers != null && msg.toUsers.isNotEmpty) {
        map['tos'] = msg.toUsers;
      }
      map['direction'] = msg.direction.index;
      map['status'] = msg.status.index;
      map['serverTime'] = msg.serverTime;

      MessagePayload payload = await msg.content.encode();
      map['ctype'] = payload.contentType;
      map['csc'] = payload.searchableContent;
      map['cpc'] = payload.pushContent;
      map['cpd'] = payload.pushData;
      map['cc'] = payload.content;
      if (payload.binaryContent != null) {
        map['cbc'] = Base64Encoder().convert(payload.binaryContent);
      }
      map['cmt'] = payload.mentionedType;
      if (payload.mentionedTargets != null &&
          payload.mentionedTargets.isNotEmpty) {
        map['cmts'] = payload.mentionedTargets;
      }
      map['ce'] = payload.extra;
      map['mt'] = payload.mediaType.index;
      if (payload.remoteMediaUrl != null) {
        map['mru'] = payload.remoteMediaUrl;
      }
      ms.add(map);
    }

    payload.binaryContent = utf8.encode(json.encode({'ms': ms}));
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
