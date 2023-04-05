enum ChatroomState { Normal, NoStarted, End }

class ChatroomInfo {
  ChatroomInfo({this.state = ChatroomState.Normal, this.memberCount = 0, this.createDt = 0,
    this.updateDt = 0});
  late String chatroomId;
  String? title;
  String? desc;
  String? portrait;
  String? extra;

  ChatroomState state;
  int memberCount;
  int createDt;
  int updateDt;
}
