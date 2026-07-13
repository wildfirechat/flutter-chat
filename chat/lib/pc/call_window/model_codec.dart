import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';

/// 用户/群成员信息跨窗口编解码。
class ModelCodec {
  static Map<String, dynamic> encodeUserInfo(UserInfo user) {
    return {
      // 使用与 IM SDK proto 一致的 'uid'，避免 Call 窗口侧 _convertProtoUserInfo 解析失败。
      'uid': user.userId,
      'name': user.name,
      'displayName': user.displayName,
      'gender': user.gender,
      'portrait': user.portrait,
      'mobile': user.mobile,
      'email': user.email,
      'address': user.address,
      'company': user.company,
      'social': user.social,
      'extra': user.extra,
      'friendAlias': user.friendAlias,
      'groupAlias': user.groupAlias,
      'updateDt': user.updateDt,
      'type': user.type,
      'deleted': user.deleted,
    };
  }

  static UserInfo decodeUserInfo(Map<String, dynamic> map) {
    final user = UserInfo(
      (map['uid'] ?? map['userId']) as String,
      gender: map['gender'] as int? ?? 0,
      updateDt: map['updateDt'] as int? ?? 0,
      type: map['type'] as int? ?? 0,
      deleted: map['deleted'] as int? ?? 0,
    );
    user.name = map['name'] as String? ?? '';
    user.displayName = map['displayName'] as String?;
    user.portrait = map['portrait'] as String?;
    user.mobile = map['mobile'] as String?;
    user.email = map['email'] as String?;
    user.address = map['address'] as String?;
    user.company = map['company'] as String?;
    user.social = map['social'] as String?;
    user.extra = map['extra'] as String?;
    user.friendAlias = map['friendAlias'] as String?;
    user.groupAlias = map['groupAlias'] as String?;
    return user;
  }

  static Map<String, dynamic> encodeGroupMember(GroupMember member) {
    return {
      'memberId': member.memberId,
      'alias': member.alias,
      'extra': member.extra,
      'type': member.type.index,
      'createDt': member.createDt,
      'updateDt': member.updateDt,
    };
  }

  static GroupMember decodeGroupMember(Map<String, dynamic> map) {
    final member = GroupMember();
    member.memberId = map['memberId'] as String;
    member.alias = map['alias'] as String?;
    member.extra = map['extra'] as String?;
    member.type = GroupMemberType.values[map['type'] as int];
    member.createDt = map['createDt'] as int? ?? 0;
    member.updateDt = map['updateDt'] as int? ?? 0;
    return member;
  }
}
