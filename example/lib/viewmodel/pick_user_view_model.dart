import 'dart:ffi';

import 'package:flutter/widgets.dart';
import 'package:imclient/model/user_info.dart';

class PickUserViewModel extends ChangeNotifier {
  List<UserInfo> _users = [];
  final List<UserInfo> _pickedUsers = [];
  List<String> _uncheckableUserIds = [];
  List<String> _disabledAndCheckedUserIds = [];
  int _maxPickCount = 0;

  List<UserInfo> get pickedUsers => _pickedUsers;

  List<UserInfo> get users => _users;

  List<String> get uncheckableUserIds => _uncheckableUserIds;

  List<String> get disabledAndCheckedUserIds => _disabledAndCheckedUserIds;

  void setup(List<UserInfo> users, {int maxPickCount = 1024, List<String>? uncheckableUserIds, List<String>? disabledUserIds}) {
    _users = users;
    _maxPickCount = maxPickCount;
    _uncheckableUserIds = uncheckableUserIds ?? [];
    _disabledAndCheckedUserIds = disabledUserIds ?? [];
    notifyListeners();
  }

  bool isCheckable(String userId) {
    return !_uncheckableUserIds.contains(userId) && !_disabledAndCheckedUserIds.contains(userId);
  }

  bool isChecked(String userId) {
    return _pickedUsers.any((u) => u.userId == userId);
  }

  bool pickUser(UserInfo userInfo, bool pick) {
    if (pick && _pickedUsers.length >= _maxPickCount) {
      return false;
    }
    if (_uncheckableUserIds.any((u) => u == userInfo.userId) || _disabledAndCheckedUserIds.any((u) => u == userInfo.userId)) {
      return false;
    }
    if (pick && !_pickedUsers.contains(userInfo)) {
      _pickedUsers.add(userInfo);
    } else if (!pick && _pickedUsers.contains(userInfo)) {
      _pickedUsers.remove(userInfo);
    }
    notifyListeners();
    return true;
  }
}
