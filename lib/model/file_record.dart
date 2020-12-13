import 'package:flutter_imclient/model/conversation.dart';

class FileRecord {
  FileRecord(
      {this.messageUid = 0,
      this.size = 0,
      this.downloadCount = 0,
      this.timestamp = 0});
  Conversation conversation;
  int messageUid;
  String userId;
  String name;
  String url;
  int size;
  int downloadCount;
  int timestamp;
}
