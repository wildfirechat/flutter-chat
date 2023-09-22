import 'dart:convert';
import 'dart:typed_data';

import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';
import 'package:momentclient/momentclient.dart';

import 'momentclient_method_channel.dart';



// ignore: non_constant_identifier_names
MessageContent MomentCommentMessageContentCreator() {
  return MomentCommentMessageContent();
}

const commentContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_COMMENT,
    MessageFlag.PERSIST_AND_COUNT, MomentCommentMessageContentCreator);

class MomentCommentMessageContent extends MessageContent {
  late int feedId;
  late int commentId;
  int? replyCommentId;
  late String sender;
  late WFMCommentType type;
  String? text;

  String? replyTo;
  late int serverTime;

  late WFMContentType feedType;
  String? feedText;
  List<FeedEntry>? feedMedias;
  late String feedSender;

  @override
  MessageContentMeta get meta => commentContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);

    Map<dynamic, dynamic> map = json.decode(
        utf8.decode(payload.binaryContent!));
    feedId = map["feedId"];
    commentId = map["commentId"];
    replyCommentId = map["replyCommentId"];
    serverTime = map["serverTime"];
    type = WFMCommentType.values[map['type']];
    sender = map['sender'];
    text = map['text'];
    replyTo = map['replyTo'];
    extra = map['extra'];

    feedType = WFMContentType.values[map['ftype']];
    feedSender = map['fsender'];
    feedText = map['fcontent'];
    if(map['fmedias'] != null) {
      List<dynamic> ms = map['fmedias'];
      feedMedias = [];
      for (var value in ms) {
        if(value is Map) {
          feedMedias!.add(MethodChannelMomentClient.entryFromMap(value));
        }
      }
    }
    text = payload.searchableContent;

  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();

    payload.searchableContent = text;
    Map<String, dynamic> map = {'feedId':feedId, 'commentId':commentId, 'type':type.index, 'sender':sender, 'serverTime':serverTime, 'ftype':feedType.index, 'fsender':feedSender};
    if(text != null) {
      map['text'] = text;
    }
    if(replyCommentId != null) {
      map['replyCommentId'] = replyCommentId;
    }
    if(replyTo != null) {
      map['replyTo'] = replyTo;
    }
    if(feedText != null) {
      map['fcontent'] = feedText;
    }
    if(feedMedias != null && feedMedias!.isNotEmpty) {
      map['fMedias'] = MethodChannelMomentClient.feedEntryList2Map(feedMedias!);
    }
    if(extra != null) {
      map['e'] = extra;
    }
    payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(map)));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return "";
  }
}
