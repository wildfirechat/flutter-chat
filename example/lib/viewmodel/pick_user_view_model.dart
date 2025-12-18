import 'package:flutter/widgets.dart';
import 'package:imclient/model/user_info.dart';
import 'package:pinyin/pinyin.dart';
import 'package:wfc_example/config.dart';

class UIPickUserInfo {
  String category;
  bool showCategory;
  UserInfo userInfo;

  UIPickUserInfo(this.category, this.showCategory, this.userInfo);
}

class PickUserViewModel extends ChangeNotifier {
  List<UIPickUserInfo> _users = [];
  final List<UserInfo> _pickedUsers = [];
  List<String> _uncheckableUserIds = [];
  List<String> _disabledAndCheckedUserIds = [];
  int _maxPickCount = 0;

  List<UserInfo> get pickedUsers => _pickedUsers;

  List<UIPickUserInfo> get userList => _users;

  List<String> get uncheckableUserIds => _uncheckableUserIds;

  List<String> get disabledAndCheckedUserIds => _disabledAndCheckedUserIds;

  void setup(List<UserInfo> users, {int maxPickCount = 1024, List<String>? uncheckableUserIds, List<String>? disabledUserIds, bool showMentionAll = false}) {
    _maxPickCount = maxPickCount;
    _uncheckableUserIds = uncheckableUserIds ?? [];
    _disabledAndCheckedUserIds = disabledUserIds ?? [];

    _users = [];
    if (showMentionAll) {
      UserInfo all = UserInfo();
      all.userId = 'All';
      all.displayName = '所有人';
      _users.add(UIPickUserInfo("", false, all));
    }

    for (var userInfo in users) {
      userInfo.displayName = userInfo.displayName ?? '<${userInfo.userId}>';
      var category = '{';

      if (Config.AI_ROBOTS.contains(userInfo.userId)) {
        category = "AI 机器人";
      } else {
        var runes = userInfo.displayName!.runes.toList();
        if (ChineseHelper.isChinese(String.fromCharCode(runes[0]))) {
          var firstWordPinyin = PinyinHelper.getFirstWordPinyin(userInfo.displayName!);
          category = firstWordPinyin.isNotEmpty ? firstWordPinyin.substring(0, 1).toUpperCase() : '{';
        }
      }

      _users.add(UIPickUserInfo(category, false, userInfo));
    }

    _users.sort((a, b) {
      if (a.userInfo.userId == 'All') return -1;
      if (b.userInfo.userId == 'All') return 1;

      if (a.category == "AI 机器人" && b.category != "AI 机器人") return -1;
      if (a.category != "AI 机器人" && b.category == "AI 机器人") return 1;

      if (a.category == b.category) {
        return a.userInfo.displayName!.compareTo(b.userInfo.displayName!);
      }
      return a.category.compareTo(b.category);
    });

    var lastCategory = "";
    for (var contactInfo in _users) {
      if (contactInfo.userInfo.userId == 'All') {
        contactInfo.showCategory = false;
        continue;
      }
      if (contactInfo.category == lastCategory) {
        contactInfo.showCategory = false;
      } else {
        contactInfo.showCategory = true;
      }
      lastCategory = contactInfo.category;
    }

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
