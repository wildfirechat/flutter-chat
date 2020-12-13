import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/model/conversation.dart';

class ConversationSearchInfo {
  ConversationSearchInfo({this.marchedCount = 0, this.timestamp = 0});
  Conversation conversation;
  Message marchedMessage;
  int marchedCount;
  int timestamp;
}
