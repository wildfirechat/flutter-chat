import 'package:flutter_imclient/model/conversation.dart';

class ReadReport {
  ReadReport({this.readDt = 0});
  Conversation conversation;
  String userId;
  int readDt;
}
