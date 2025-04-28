import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/friend_request.dart';
import 'package:pinyin/pinyin.dart';
import 'package:wfc_example/contact/contact_info.dart';

class ContactListViewModel extends ChangeNotifier {
  List<ContactInfo> _contactList = [];
  List<String> _friendList = [];
  List<FriendRequest> _newFriendRequestList = [];

  late StreamSubscription<FriendUpdateEvent> _friendUpdatedSubscription;
  late StreamSubscription<FriendRequestUpdateEvent> _friendRequestUpdatedSubscription;
  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;
  // TODO 星标利息人
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

    _loadContactList(true);
    _loadFriendRequestListAndNotify();
  }

  List<ContactInfo> get contactList => _contactList;

  List<FriendRequest> get newFriendRequestList => _newFriendRequestList;

  _loadFriendRequestListAndNotify() {
    Imclient.getIncommingFriendRequest().then((friendRequests) {
      _newFriendRequestList = friendRequests;
      notifyListeners();
    });
  }

  void _loadContactList([refresh = false]) async {
    _friendList = await Imclient.getMyFriendList(refresh: refresh);

    List<ContactInfo> contactList = [];
    var userInfos = await Imclient.getUserInfos(_friendList);
    for (var userInfo in userInfos) {
      userInfo.displayName = userInfo.displayName ?? '<${userInfo.userId}>';
      var runes = userInfo.displayName!.runes.toList();
      var firstWordPinyinLetter = '{';
      if (ChineseHelper.isChinese(String.fromCharCode(runes[0]))) {
        var firstWordPinyin = PinyinHelper.getFirstWordPinyin(userInfo.displayName!);
        firstWordPinyinLetter = firstWordPinyin.isNotEmpty ? firstWordPinyin.substring(0, 1).toUpperCase() : '{';
      }

      contactList.add(ContactInfo(firstWordPinyinLetter, false, userInfo));
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
  }
}
