enum GroupMemberType { Normal, Manager, Owner, Muted, Allowed }

class GroupMember {
  GroupMember(
      {this.type = GroupMemberType.Normal,
      this.createDt = 0,
      this.updateDt = 0});
  String groupId;
  String memberId;
  GroupMemberType type;
  String alias;
  int createDt;
  int updateDt;
}
