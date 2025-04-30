enum GroupType { Normal, Free, Restricted, Organization }

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
      this.superGroup = 0,
      this.deleted = 0,
      this.memberDt = 0,
      this.updateDt = 0});
  late String target;
  GroupType type;
  String? name;
  String? portrait;
  int memberCount;
  String? owner;
  String? extra;
  String? remark;
  int mute;
  int joinType;
  int privateChat;
  int searchable;
  int historyMessage;
  int maxMemberCount;
  int superGroup;
  int deleted;
  int memberDt;
  int updateDt;

  @override
  bool operator ==(Object other) =>
      identical(this, other)
          || (other is GroupInfo &&
              runtimeType == other.runtimeType &&
              target == other.target &&
              updateDt == other.updateDt);

  @override
  int get hashCode =>
      target.hashCode ^
      type.hashCode ^
      name.hashCode ^
      portrait.hashCode ^
      memberCount.hashCode ^
      owner.hashCode ^
      extra.hashCode ^
      remark.hashCode ^
      mute.hashCode ^
      joinType.hashCode ^
      privateChat.hashCode ^
      searchable.hashCode ^
      historyMessage.hashCode ^
      maxMemberCount.hashCode ^
      superGroup.hashCode ^
      deleted.hashCode ^
      memberDt.hashCode ^
      updateDt.hashCode;
}
