
import '../model/message_payload.dart';
import 'message_content.dart';

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
