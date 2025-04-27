import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';

class UserViewModel extends ChangeNotifier {
  static final Map<String, UserInfo> _userList = {};

  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;

  UserViewModel() {
    _userInfoUpdatedSubscription = Imclient.IMEventBus.on<UserInfoUpdatedEvent>().listen((event) {
      for (var user in event.userInfos) {
        _userList[user.userId] = user;
      }
      notifyListeners();
    });
  }

  UserInfo? getUserInfo(String userId, {String? groupId}) {
    var userInfo = _userList[userId];
    if (userInfo != null) {
      return userInfo;
    }
    Imclient.getUserInfo(userId, groupId: groupId).then((userInfo) {
      if (userInfo == null) {
        return;
      }
      _userList[userId] = userInfo;
      notifyListeners();
    });
    return null;
  }

  @override
  void dispose() {
    super.dispose();
    _userInfoUpdatedSubscription.cancel();
  }
}
