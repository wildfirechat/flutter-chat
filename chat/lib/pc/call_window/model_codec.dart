import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';

/// 用户/群成员信息的跨窗口编码(主窗口侧)。
///
/// 线格式与 imclient 的 proto map 保持一致(UserInfo 主键 'uid'、
/// GroupMember 的 'type' 为枚举 index),子窗口把返回的 map 直接交给
/// ImclientPlatform 的 _convertProtoUserInfo / _convertProtoGroupMember
/// 解码,因此这里不需要对应的 decode 实现。
class ModelCodec {
  static Map<String, dynamic> encodeUserInfo(UserInfo user) {
    return {
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
}
