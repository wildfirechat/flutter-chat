import 'dart:convert';
import 'dart:typed_data';

import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/message_payload.dart';
import 'package:momentclient/momentclient.dart';

import 'momentclient_method_channel.dart';


// ignore: non_constant_identifier_names
MessageContent MomentFeedMessageContentCreator() {
  return MomentFeedMessageContent();
}

const feedContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_FEED,
    MessageFlag.PERSIST_AND_COUNT, MomentFeedMessageContentCreator);

class MomentFeedMessageContent extends MessageContent {
  late int feedId;
  late WFMContentType type;
  String? text;
  List<FeedEntry>? medias;
  late String sender;
  List<String>? toUsers;
  List<String>? excludeUsers;

  @override
  MessageContentMeta get meta => feedContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);

    Map<dynamic, dynamic> map = json.decode(
        utf8.decode(payload.binaryContent!));
    feedId = map["feedId"];
    type = map['t'];
    sender = map['s'];
    text = map['c'];
    List<dynamic> ms = map['ms'];
    medias = [];
    for (var value in ms) {
      if(value is Map) {
        medias!.add(MethodChannelMomentClient.entryFromMap(value));
      }
    }
      extra = map['e'];
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();

    payload.searchableContent = text;
    Map<String, dynamic> map = {'feedId':feedId, 't':type.index, 's':sender};
    if(text != null) {
      map['c'] = text;
    }
    if(medias != null && medias!.isNotEmpty) {
      map['ms'] = MethodChannelMomentClient.feedEntryList2Map(medias!);
    }
    if(toUsers != null && toUsers!.isNotEmpty) {
      map['to'] = toUsers;
    }
    if(excludeUsers != null && excludeUsers!.isNotEmpty) {
      map['ex'] = excludeUsers;
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
