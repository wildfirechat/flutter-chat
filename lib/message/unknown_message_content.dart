import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/model/message_payload.dart';

class UnknownMessageContent extends MessageContent {
  MessagePayload rawPayload;
  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    rawPayload = payload;
  }

  @override
  Future<MessagePayload> encode() async{
    return rawPayload;
  }
}
