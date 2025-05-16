import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/friend_request.dart';
import 'package:pinyin/pinyin.dart';
import 'package:wfc_example/repo/user_repo.dart';
import 'package:wfc_example/ui_model/ui_contact_info.dart';

class ContactListViewModel extends ChangeNotifier {
  List<UIContactInfo> _contactList = [];
  List<String> _friendList = [];
  List<FriendRequest> _newFriendRequestList = [];
  int _unreadFriendRequestCount = 0;

  late StreamSubscription<FriendUpdateEvent> _friendUpdatedSubscription;
  late StreamSubscription<FriendRequestUpdateEvent> _friendRequestUpdatedSubscription;
  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;
  late StreamSubscription<ClearFriendRequestUnreadEvent> _clearFriendRequestSubscription;

  // TODO 星标联系人
  late StreamSubscription<UserSettingUpdatedEvent> _userSettingUpdatedSubscription;

  ContactListViewModel() {
    _friendUpdatedSubscription = Imclient.IMEventBus.on<FriendUpdateEvent>().listen((event) {
      _loadContactList(false);
    });
    _friendRequestUpdatedSubscription = Imclient.IMEventBus.on<FriendRequestUpdateEvent>().listen((event) {
      _loadFriendRequestListAndNotify();
    });
    _userInfoUpdatedSubscription = Imclient.IMEventBus.on<UserInfoUpdatedEvent>().listen((event) {
      // TODO 优化
      //var updatedUserInfos = event.userInfos;
      _loadContactList();
    });
    _clearFriendRequestSubscription = Imclient.IMEventBus.on<ClearFriendRequestUnreadEvent>().listen((event) {
      _loadFriendRequestListAndNotify();
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

  void _loadContactList([refresh = false]) async {
    _friendList = await Imclient.getMyFriendList(refresh: refresh);

    List<UIContactInfo> contactList = [];
    var userInfos = await UserRepo.getUserInfos(_friendList);
    for (var userInfo in userInfos) {
      userInfo.displayName = userInfo.displayName ?? '<${userInfo.userId}>';
      var runes = userInfo.displayName!.runes.toList();
      var firstWordPinyinLetter = '{';
      if (ChineseHelper.isChinese(String.fromCharCode(runes[0]))) {
        var firstWordPinyin = PinyinHelper.getFirstWordPinyin(userInfo.displayName!);
        firstWordPinyinLetter = firstWordPinyin.isNotEmpty ? firstWordPinyin.substring(0, 1).toUpperCase() : '{';
      }

      contactList.add(UIContactInfo(firstWordPinyinLetter, false, userInfo));
    }

    contactList.sort((a, b) {
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
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
    _friendUpdatedSubscription.cancel();
    _friendRequestUpdatedSubscription.cancel();
    _userInfoUpdatedSubscription.cancel();
    _clearFriendRequestSubscription.cancel();
  }
}
