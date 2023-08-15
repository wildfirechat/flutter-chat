

// ignore: non_constant_identifier_names
import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import '../model/quote_info.dart';
import 'message.dart';
import 'message_content.dart';

MessageContent TextMessageContentCreator() {
  return TextMessageContent("");
}

const textContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_TEXT,
    MessageFlag.PERSIST_AND_COUNT, TextMessageContentCreator);

class TextMessageContent extends MessageContent {
  TextMessageContent(this.text);
  String text;
  QuoteInfo? quoteInfo;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if(payload.searchableContent != null) {
      text = payload.searchableContent!;
    }
    if(payload.binaryContent != null) {
      Map<dynamic, dynamic> map = json.decode(
          utf8.decode(payload.binaryContent!));
      Map<dynamic, dynamic> quote = map['quote'];
      quoteInfo = QuoteInfo(quote['u']);
      if(quote['i'] != null) {
        quoteInfo!.userId = quote['i'];
      }
      if(quote['n'] != null) {
        quoteInfo!.userDisplayName = quote['n'];
      }
      if(quote['d'] != null) {
        quoteInfo!.messageDigest = quote['d'];
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = text;
    if(quoteInfo != null) {
      Map<dynamic, dynamic> quote = {"u":quoteInfo!.messageUid};
      if(quoteInfo!.userId != null) {
        quote['i'] = quoteInfo!.userId;
      }
      if(quoteInfo!.userDisplayName != null) {
        quote['n'] = quoteInfo!.userDisplayName;
      }
      if(quoteInfo!.messageDigest != null) {
        quote['d'] = quoteInfo!.messageDigest;
      }
      payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode({
        'quote': quote
      })));
    }
    return payload;
  }


  @override
  Future<String> digest(Message message) async {
    return text;
  }

  @override
  MessageContentMeta get meta => textContentMeta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextMessageContent &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;
}
