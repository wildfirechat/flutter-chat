import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:imclient/model/user_info.dart';
import 'package:pinyin/pinyin.dart';
import 'package:chat/config.dart';

class UIPickUserInfo {
  String category;
  bool showCategory;
  UserInfo userInfo;
  // setup 时预算的拼音检索串，避免搜索时逐键重算
  String pinyin;
  String shortPinyin;

  UIPickUserInfo(this.category, this.showCategory, this.userInfo,
      {this.pinyin = '', this.shortPinyin = ''});
}

class PickUserViewModel extends ChangeNotifier {
  List<UIPickUserInfo> _users = [];
  final List<UserInfo> _pickedUsers = [];
  List<String> _uncheckableUserIds = [];
  List<String> _disabledAndCheckedUserIds = [];
  int _maxPickCount = 0;

  List<UserInfo> get pickedUsers => _pickedUsers;

  List<String> get uncheckableUserIds => _uncheckableUserIds;

  List<String> get disabledAndCheckedUserIds => _disabledAndCheckedUserIds;

  String _query = '';
  List<UIPickUserInfo> _filteredUsers = [];
  Timer? _searchDebounceTimer;

  List<UIPickUserInfo> get userList => _query.isEmpty ? _users : _filteredUsers;

  bool get isSearching => _query.isNotEmpty;

  void search(String query) {
    // 输入防抖：合并连续按键，避免每个字符都全量过滤+notify
    if (_searchDebounceTimer?.isActive ?? false) _searchDebounceTimer!.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      _query = query;
      if (query.isEmpty) {
        _filteredUsers = [];
      } else {
        var lowerQuery = query.toLowerCase();
        _filteredUsers = _users.where((u) {
          if (u.userInfo.userId == '@all') return false;
          String name = u.userInfo.displayName ?? '';

          return name.contains(query) ||
              u.pinyin.contains(lowerQuery) ||
              u.shortPinyin.contains(lowerQuery);
        }).toList();
      }
      notifyListeners();
    });
  }

  void setup(List<UserInfo> users,
      {int maxPickCount = 1024,
      List<String>? uncheckableUserIds,
      List<String>? disabledUserIds,
      bool showMentionAll = false}) {
    _maxPickCount = maxPickCount;
    _uncheckableUserIds = uncheckableUserIds ?? [];
    _disabledAndCheckedUserIds = disabledUserIds ?? [];

    _users = [];
    if (showMentionAll) {
      UserInfo all = UserInfo('@all');
      all.displayName = 'All';
      _users.add(UIPickUserInfo("", false, all));
    }

    for (var userInfo in users) {
      userInfo.displayName = userInfo.displayName ?? '<${userInfo.userId}>';
      var category = '{';

      if (Config.AI_ROBOTS.contains(userInfo.userId)) {
        category = "AI";
      } else {
        var runes = userInfo.displayName!.runes.toList();
        if (runes.isNotEmpty &&
            ChineseHelper.isChinese(String.fromCharCode(runes[0]))) {
          var firstWordPinyin =
              PinyinHelper.getFirstWordPinyin(userInfo.displayName!);
          category = firstWordPinyin.isNotEmpty
              ? firstWordPinyin.substring(0, 1).toUpperCase()
              : '{';
        }
      }

      // 预算拼音检索串并缓存，搜索时只做 contains 匹配
      var name = userInfo.displayName!;
      var pinyin = PinyinHelper.getPinyinE(name,
          separator: "", defPinyin: '#', format: PinyinFormat.WITHOUT_TONE);
      var shortPinyin = PinyinHelper.getShortPinyin(name);
      _users.add(UIPickUserInfo(category, false, userInfo,
          pinyin: pinyin, shortPinyin: shortPinyin));
    }

    _users.sort((a, b) {
      if (a.userInfo.userId == '@all') return -1;
      if (b.userInfo.userId == '@all') return 1;

      if (a.category == "AI" && b.category != "AI") return -1;
      if (a.category != "AI" && b.category == "AI") return 1;

      if (a.category == b.category) {
        return a.userInfo.displayName!.compareTo(b.userInfo.displayName!);
      }
      return a.category.compareTo(b.category);
    });

    var lastCategory = "";
    for (var contactInfo in _users) {
      if (contactInfo.userInfo.userId == '@all') {
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
    return !_uncheckableUserIds.contains(userId) &&
        !_disabledAndCheckedUserIds.contains(userId);
  }

  bool isChecked(String userId) {
    return _pickedUsers.any((u) => u.userId == userId);
  }

  bool pickUser(UserInfo userInfo, bool pick) {
    if (_uncheckableUserIds.any((u) => u == userInfo.userId) ||
        _disabledAndCheckedUserIds.any((u) => u == userInfo.userId)) {
      return false;
    }
    // 按 userId 判定是否已选:同一用户在好友列表与组织架构里可能是不同的 UserInfo 实例
    // (updateDt/别名不同导致 == 不等),用 id 去重才能正确增删。
    final index = _pickedUsers.indexWhere((u) => u.userId == userInfo.userId);
    if (pick) {
      if (index < 0) {
        if (_pickedUsers.length >= _maxPickCount) {
          return false;
        }
        _pickedUsers.add(userInfo);
      }
    } else if (index >= 0) {
      _pickedUsers.removeAt(index);
    }
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    super.dispose();
    _searchDebounceTimer?.cancel();
  }
}
