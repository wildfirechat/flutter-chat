class UserInfo {
  UserInfo({this.gender = 0, this.updateDt = 0, this.type = 0, this.deleted = 0});

  //用户ID
  late String userId;

  //名称
  late String name;

  //显示的名称
  String? displayName;

  //性别
  int gender;

  //头像
  String? portrait;

  //手机号
  String? mobile;

  //邮箱
  String? email;

  //地址
  String? address;

  //公司信息
  String? company;

  //社交信息
  String? social;

  //扩展信息
  String? extra;

  //好友备注
  String? friendAlias;

  //群昵称
  String? groupAlias;

  //更新时间
  int updateDt;

  //用户类型
  int type;

  //是否被删除用户
  int deleted;

  String getReadableName() {
    String readableName = userId;
    if (friendAlias != null && friendAlias!.isNotEmpty) {
      readableName = friendAlias!;
    } else if (groupAlias != null && groupAlias!.isNotEmpty) {
      readableName = groupAlias!;
    } else {
      if (displayName != null) {
        readableName = displayName!;
      }
    }
    return readableName;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other)
          || (other is UserInfo
          && runtimeType == other.runtimeType
          && userId == other.userId
          && updateDt == other.updateDt
          // friendAlis 更新时，不会触发 updateDt 更新
          && friendAlias == other.friendAlias
          && groupAlias == other.groupAlias
      );

  @override
  int get hashCode =>
      userId.hashCode ^
      updateDt.hashCode ^
      (friendAlias != null ? friendAlias.hashCode : 0) ^
      (groupAlias != null ? groupAlias.hashCode : 0);
}
