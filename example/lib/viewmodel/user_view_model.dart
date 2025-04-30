import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:wfc_example/repo/user_repo.dart';

class UserViewModel extends ChangeNotifier {
  UserCacheRepo userRepo = UserCacheRepo();

  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;

  UserViewModel() {
    _userInfoUpdatedSubscription = Imclient.IMEventBus.on<UserInfoUpdatedEvent>().listen((event) {
      for (var user in event.userInfos) {
        userRepo.putUserInfo(user);
      }
      notifyListeners();
    });
  }

  Future<UserInfo?> getUserInfo(String userId, {String? groupId}) async {
    var userInfo = userRepo.getUserInfo(userId, groupId: groupId);
    if (userInfo != null) {
      return userInfo;
    }
    userInfo = await Imclient.getUserInfo(userId, groupId: groupId);
    if (userInfo != null) {
      userRepo.putUserInfo(userInfo);
    }
    return userInfo;
  }

  @override
  void dispose() {
    super.dispose();
    _userInfoUpdatedSubscription.cancel();
  }
}
