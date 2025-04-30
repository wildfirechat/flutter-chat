import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';

class UserRepo {
  static final Map<String, UserInfo> _userMap = {};

  static Future<UserInfo?> getUserInfo(String userId) async {
    var info = _userMap[userId];
    if (info == null) {
      info = await Imclient.getUserInfo(userId);
      if (info != null) {
        _userMap[userId] = info;
      }
    }
    return info;
  }

  static void putUserInfo(UserInfo userInfo) {
    _userMap[userInfo.userId] = userInfo;
  }
}
