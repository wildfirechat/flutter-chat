import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';

class UserViewModel extends ChangeNotifier {
  static final Map<String, UserInfo> _userMap = {};

  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;

  UserViewModel() {
    _userInfoUpdatedSubscription = Imclient.IMEventBus.on<UserInfoUpdatedEvent>().listen((event) {
      for (var user in event.userInfos) {
        _userMap[user.userId] = user;
      }
      notifyListeners();
    });
  }

  UserInfo? getUserInfo(String userId, {String? groupId}) {
    var userInfo = _userMap[userId];
    if (userInfo != null) {
      return userInfo;
    }
    Imclient.getUserInfo(userId, groupId: groupId).then((info) {
      if (info == null) {
        return;
      }
      _userMap[userId] = info;
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
