enum ChatroomState { Normal, NoStarted, End }

class ChatroomInfo {
  String chatroomId;
  String title;
  String desc;
  String portrait;
  String extra;

  ChatroomState state;
  int memberCount;
  int createDt;
  int updateDt;
}
