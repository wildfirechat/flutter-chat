
import '../model/message_payload.dart';
import 'message_content.dart';

class UnknownMessageContent extends MessageContent {
  late MessagePayload rawPayload;
  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    rawPayload = payload;
  }

  @override
  MessagePayload encode() {
    return rawPayload;
  }
}
