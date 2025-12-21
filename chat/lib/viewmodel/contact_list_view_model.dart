import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/friend_request.dart';
import 'package:pinyin/pinyin.dart';
import 'package:chat/config.dart';
import 'package:chat/repo/user_repo.dart';
import 'package:chat/ui_model/ui_contact_info.dart';

class ContactListViewModel extends ChangeNotifier {
  List<UIContactInfo> _contactList = [];
  List<FriendRequest> _newFriendRequestList = [];
  int _unreadFriendRequestCount = 0;

  late StreamSubscription<ConnectionStatusChangedEvent> _connectionStatusSubscription;
  late StreamSubscription<FriendUpdateEvent> _friendUpdatedSubscription;
  late StreamSubscription<FriendRequestUpdateEvent> _friendRequestUpdatedSubscription;
  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;
  late StreamSubscription<ClearFriendRequestUnreadEvent> _clearFriendRequestSubscription;

  // TODO 星标联系人
  late StreamSubscription<UserSettingUpdatedEvent> _userSettingUpdatedSubscription;

  ContactListViewModel() {
    _friendUpdatedSubscription = Imclient.IMEventBus.on<FriendUpdateEvent>().listen((event) {
      _loadContactList(false);
      notifyListeners();
    });
    _friendRequestUpdatedSubscription = Imclient.IMEventBus.on<FriendRequestUpdateEvent>().listen((event) {
      _loadFriendRequestListAndNotify();
    });
    _userInfoUpdatedSubscription = Imclient.IMEventBus.on<UserInfoUpdatedEvent>().listen((event) {
      debugPrint('userInfo updated to load contactViewModel');
      _loadContactList();
      notifyListeners();
    });
    _clearFriendRequestSubscription = Imclient.IMEventBus.on<ClearFriendRequestUnreadEvent>().listen((event) {
      _loadFriendRequestListAndNotify();
    });

    _connectionStatusSubscription = Imclient.IMEventBus.on<ConnectionStatusChangedEvent>().listen((event) {
      if(event.connectionStatus == kConnectionStatusConnected) {
        _loadContactList(true);
        notifyListeners();
      }
    });

    _loadContactList(true);
    _loadFriendRequestListAndNotify();
  }

  List<UIContactInfo> get contactList => _contactList;

  List<FriendRequest> get newFriendRequestList => _newFriendRequestList;

  int get unreadFriendRequestCount => _unreadFriendRequestCount;

  void clearUnreadFriendRequestStatus() {
    Imclient.clearUnreadFriendRequestStatus();
    // will notifyListeners by the event
  }

  _loadFriendRequestListAndNotify() async {
    _newFriendRequestList = await Imclient.getIncommingFriendRequest();
    _unreadFriendRequestCount = await Imclient.getUnreadFriendRequestStatus();
    notifyListeners();
  }

  void _loadContactList([bool refresh = false]) async {
    List<UIContactInfo> contactList = [];
    var userInfos = await UserRepo.getFriendUserInfos(refresh : refresh);
    for (var userInfo in userInfos) {
      userInfo.displayName = userInfo.displayName ?? '<${userInfo.userId}>';
      var runes = userInfo.displayName!.runes.toList();
      var firstWordPinyinLetter = '{';
      if (runes.isNotEmpty && ChineseHelper.isChinese(String.fromCharCode(runes[0]))) {
        var firstWordPinyin = PinyinHelper.getFirstWordPinyin(userInfo.displayName!);
        firstWordPinyinLetter = firstWordPinyin.isNotEmpty ? firstWordPinyin.substring(0, 1).toUpperCase() : '{';
      }

      contactList.add(UIContactInfo(firstWordPinyinLetter, false, userInfo));
    }

    if (Config.AI_ROBOTS.isNotEmpty) {
      for (var robotId in Config.AI_ROBOTS) {
        var userInfo = await Imclient.getUserInfo(robotId, refresh: refresh);
        if (userInfo != null) {
          userInfo.displayName = userInfo.displayName ?? '<${userInfo.userId}>';
          contactList.add(UIContactInfo("AI 机器人", false, userInfo));
        }
      }
    }

    contactList.sort((a, b) {
      if (a.category == "AI 机器人" && b.category != "AI 机器人") return -1;
      if (a.category != "AI 机器人" && b.category == "AI 机器人") return 1;

      if (a.category == b.category) {
        return a.userInfo.displayName!.compareTo(b.userInfo.displayName!);
      }
      return a.category.compareTo(b.category);
    });

    var lastCategory = "";
    for (var contactInfo in contactList) {
      if (contactInfo.category == lastCategory) {
        contactInfo.showCategory = false;
      } else {
        contactInfo.showCategory = true;
      }
      lastCategory = contactInfo.category;
    }

    _contactList = contactList;
  }

  @override
  void dispose() {
    super.dispose();
    _friendUpdatedSubscription.cancel();
    _friendRequestUpdatedSubscription.cancel();
    _userInfoUpdatedSubscription.cancel();
    _clearFriendRequestSubscription.cancel();
    _connectionStatusSubscription.cancel();
  }
}
