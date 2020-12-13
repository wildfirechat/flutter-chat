class UserInfo {
  UserInfo(
      {this.gender = 0, this.updateDt = 0, this.type = 0, this.deleted = 0});
  //用户ID
  String userId;

  //名称
  String name;

  //显示的名称
  String displayName;

  //性别
  int gender;

  //头像
  String portrait;

  //手机号
  String mobile;

  //邮箱
  String email;

  //地址
  String address;

  //公司信息
  String company;

  //社交信息
  String social;

  //扩展信息
  String extra;

  //好友备注
  String friendAlias;

  //群昵称
  String groupAlias;

  //更新时间
  int updateDt;

  //用户类型
  int type;

  //是否被删除用户
  int deleted;
}
