import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';

class UserRepo {
  static final Map<String, UserInfo> _userMap = {};
  static final Map<String, Map<String, UserInfo>> _groupUserMap = {};

  static Future<UserInfo?> getUserInfo(String userId, {String? groupId}) async {
    var map = groupId != null ? _groupUserMap[groupId] : _userMap;
    if (groupId != null && map == null) {
      map = {};
      _groupUserMap[groupId] = map;
    }
    var info = map?[userId];
    if (info == null) {
      info = await Imclient.getUserInfo(userId, groupId: groupId);
      if (info != null && info.updateDt > 0) {
        map?[userId] = info;
      }
    }
    return info;
  }

  static Future<List<UserInfo>> getUserInfos(List<String> userIds, {String? groupId}) async {
    List<UserInfo> userInfos = [];
    userInfos = await Imclient.getUserInfos(userIds, groupId: groupId);
    var map = groupId != null ? _groupUserMap[groupId] : _userMap;
    if (groupId != null && map == null) {
      map = {};
      _groupUserMap[groupId] = map;
    }
    for (var u in userInfos) {
      if (u.updateDt > 0) {
        map?[u.userId] = u;
      }
    }
    return userInfos;
  }

// TODO 1. 用户信息更新
// TODO 2. 群成员信息更新
}
