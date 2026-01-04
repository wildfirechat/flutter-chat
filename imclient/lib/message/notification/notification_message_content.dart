
import '../message.dart';
import '../message_content.dart';

abstract class NotificationMessageContent extends MessageContent {
  Future<String> formatNotification(Message message) async {
    return "";
  }
}

