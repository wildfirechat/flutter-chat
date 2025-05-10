import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:wfc_example/repo/user_repo.dart';

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

  Future<UserInfo?> getUserInfo(String userId, {String? groupId}) async {
    var userInfo = _userMap[userId];
    if (userInfo != null) {
      return userInfo;
    }
    userInfo = await Imclient.getUserInfo(userId, groupId: groupId);
    if (userInfo == null) {
      return null;
    }
    _userMap[userId] = userInfo;
    notifyListeners();
    return userInfo;
  }

  @override
  void dispose() {
    super.dispose();
    _userInfoUpdatedSubscription.cancel();
  }
}
