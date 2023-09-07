enum GroupMemberType { Normal, Manager, Owner, Muted, Deleted, Allowed }

class GroupMember {
  GroupMember(
      {this.type = GroupMemberType.Normal,
      this.createDt = 0,
      this.updateDt = 0});
  late String groupId;
  late String memberId;
  GroupMemberType type;
  String? alias;
  String? extra;
  int createDt;
  int updateDt;
}
