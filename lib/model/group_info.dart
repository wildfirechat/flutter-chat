enum GroupType { Normal, Free, Restricted }

class GroupInfo {
  GroupInfo(
      {this.type = GroupType.Restricted,
      this.memberCount = 0,
      this.mute = 0,
      this.joinType = 0,
      this.privateChat = 0,
      this.searchable = 0,
      this.historyMessage = 0,
      this.maxMemberCount = 0,
      this.updateDt = 0});
  String target;
  GroupType type;
  String name;
  String portrait;
  int memberCount;
  String owner;
  String extra;
  int mute;
  int joinType;
  int privateChat;
  int searchable;
  int historyMessage;
  int maxMemberCount;
  int updateDt;
}
