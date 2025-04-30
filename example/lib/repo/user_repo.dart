import 'package:imclient/model/user_info.dart';

class UserCacheRepo {
  final Map<String, UserInfo> _userMap = {};
  final Map<String, UserInfo> _groupUserMap = {};

  UserCacheRepo._internal();

  factory UserCacheRepo() => _instance;

  static final UserCacheRepo _instance = UserCacheRepo._internal();

  UserInfo? getUserInfo(String userId, {String? groupId}) {
    var userInfo = groupId != null ? _groupUserMap[_groupUserKey(userId, groupId)] : _userMap[userId];
    return userInfo;
  }

  void putUserInfo(UserInfo userInfo, {String? groupId}) {
    if (groupId != null) {
      var key = _groupUserKey(userInfo.userId, groupId);
      _groupUserMap[key] = userInfo;
    } else {
      _userMap[userInfo.userId] = userInfo;
    }
  }

  _groupUserKey(String userId, String groupId) {
    return "$userId $groupId";
  }
}
