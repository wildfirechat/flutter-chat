import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/friend_request.dart';
import 'package:imclient/model/user_info.dart';
import 'package:pinyin/pinyin.dart';
import 'package:chat/config.dart';
import 'package:chat/repo/user_repo.dart';
import 'package:chat/ui_model/ui_contact_info.dart';

class ContactListViewModel extends ChangeNotifier {
  List<UIContactInfo> _contactList = [];
  List<FriendRequest> _newFriendRequestList = [];
  List<String> _favUserIds = [];
  int _unreadFriendRequestCount = 0;
  Timer? _debounceTimer;

  late StreamSubscription<ConnectionStatusChangedEvent>
      _connectionStatusSubscription;
  late StreamSubscription<FriendUpdateEvent> _friendUpdatedSubscription;
  late StreamSubscription<FriendRequestUpdateEvent>
      _friendRequestUpdatedSubscription;
  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;
  late StreamSubscription<ClearFriendRequestUnreadEvent>
      _clearFriendRequestSubscription;

  // TODO 星标联系人
  late StreamSubscription<UserSettingUpdatedEvent>
      _userSettingUpdatedSubscription;

  ContactListViewModel() {
    _friendUpdatedSubscription =
        Imclient.IMEventBus.on<FriendUpdateEvent>().listen((event) {
      _scheduleLoadContactList();
    });
    _friendRequestUpdatedSubscription =
        Imclient.IMEventBus.on<FriendRequestUpdateEvent>().listen((event) {
      _loadFriendRequestListAndNotify();
    });
    _userInfoUpdatedSubscription =
        Imclient.IMEventBus.on<UserInfoUpdatedEvent>().listen((event) {
      // 只有列表里的人变了才值得重算。会话列表滚动会不停地拉陌生人信息,
      // 而两个 tab 都是 keepAlive 的 —— 不过滤的话滑会话页就会持续触发
      // 联系人页的两万条拼音 + 排序,把 Dart 线程占满。
      if (!_affectsContactList(event.userInfos)) return;
      debugPrint('userInfo updated to load contactViewModel');
      _scheduleLoadContactList();
    });
    _clearFriendRequestSubscription =
        Imclient.IMEventBus.on<ClearFriendRequestUnreadEvent>().listen((event) {
      _loadFriendRequestListAndNotify();
    });

    _connectionStatusSubscription =
        Imclient.IMEventBus.on<ConnectionStatusChangedEvent>().listen((event) {
      if (event.connectionStatus == kConnectionStatusConnected) {
        _loadContactList(true);
        _loadFriendRequestListAndNotify();
      }
    });

    _userSettingUpdatedSubscription =
        Imclient.IMEventBus.on<UserSettingUpdatedEvent>().listen((event) {
      Imclient.getFavUsers().then((favUserIds) {
        favUserIds ??= [];
        bool changed = false;
        if (favUserIds!.length != _favUserIds.length) {
          changed = true;
        } else {
          for (var id in favUserIds!) {
            if (!_favUserIds.contains(id)) {
              changed = true;
              break;
            }
          }
        }

        if (changed) {
          _loadContactList();
        }
      });
    });

    _loadContactList(false);

    // 构造时如果已经连接，直接刷新一次，避免错过连接成功事件。
    Imclient.connectionStatus.then((status) {
      if (status == kConnectionStatusConnected) {
        _loadContactList(true);
        _loadFriendRequestListAndNotify();
      }
    });
  }

  void reset() {
    _contactList = [];
    _contactUserIds = {};
    _newFriendRequestList = [];
    _unreadFriendRequestCount = 0;
    _favUserIds = [];
    _categoryCache.clear();
    notifyListeners();
  }

  /// 当前列表里的用户 id，用于判断一次用户信息更新值不值得重算列表。
  Set<String> _contactUserIds = {};

  bool _affectsContactList(List<UserInfo> userInfos) {
    // 列表还没建好时一律放行，否则首次加载会被漏掉。
    if (_contactUserIds.isEmpty) return true;
    for (final userInfo in userInfos) {
      if (_contactUserIds.contains(userInfo.userId)) return true;
    }
    return false;
  }

  /// 全量重算(拼音 + 排序)在两万联系人时是几十毫秒的主线程活儿,
  /// 而好友/用户信息更新事件是批量到达的,必须合并成一次。
  void _scheduleLoadContactList() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      _loadContactList();
    });
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

  void refresh() {
    _loadContactList(true);
    _loadFriendRequestListAndNotify();
  }

  void setFavUser(String userId, bool fav) {
    Imclient.setFavUser(userId, fav, () {
      bool changed = false;
      if (fav) {
        if (!_favUserIds.contains(userId)) {
          _favUserIds.add(userId);
          changed = true;
        }
      } else {
        if (_favUserIds.contains(userId)) {
          _favUserIds.remove(userId);
          changed = true;
        }
      }

      if (changed) {
        _loadContactList();
        notifyListeners();
      }
    }, (error) {});
  }

  static final RegExp _asciiLetterRegExp = RegExp(r'^[a-zA-Z]$');

  /// 显示名 -> 分类字母。拼音解析在两万联系人量级上不便宜,而
  /// [UserInfoUpdatedEvent] 会反复触发全量重算,按显示名缓存结果即可复用。
  final Map<String, String> _categoryCache = {};

  String _categoryOf(String displayName) {
    var category = _categoryCache[displayName];
    if (category != null) return category;

    // '{' 在 ASCII 里排在 'Z' 之后,用它让数字/符号开头的联系人排到末尾。
    category = '{';
    if (displayName.isNotEmpty) {
      final firstChar = String.fromCharCode(displayName.runes.first);
      if (ChineseHelper.isChinese(firstChar)) {
        // 中文字符，使用拼音首字母。只有首字有意义,不必把整个名字喂进去。
        final firstWordPinyin = PinyinHelper.getFirstWordPinyin(firstChar);
        category = firstWordPinyin.isNotEmpty
            ? firstWordPinyin.substring(0, 1).toUpperCase()
            : '#';
      } else if (_asciiLetterRegExp.hasMatch(firstChar)) {
        // 英文字母，使用大写
        category = firstChar.toUpperCase();
      }
      // 其余(数字或其他字符)保持 '{'
    }

    _categoryCache[displayName] = category;
    return category;
  }

  void _loadContactList([bool refresh = false]) async {
    List<UIContactInfo> contactList = [];
    var userInfos = await UserRepo.getFriendUserInfos(refresh: refresh);
    if (_favUserIds.isEmpty) {
      List<String>? favUserIds = await Imclient.getFavUsers();
      _favUserIds = favUserIds ?? [];
    }
    final favUserIdSet = _favUserIds.toSet();

    for (var userInfo in userInfos) {
      // 检查是否是星标好友
      if (favUserIdSet.contains(userInfo.userId)) {
        contactList.add(UIContactInfo("☆", false, userInfo));
        continue;
      }

      var displayName = userInfo.friendAlias ??
          userInfo.displayName ??
          '<${userInfo.userId}>';
      contactList.add(UIContactInfo(_categoryOf(displayName), false, userInfo));
    }

    if (Config.AI_ROBOTS.isNotEmpty) {
      for (var robotId in Config.AI_ROBOTS) {
        var userInfo = await Imclient.getUserInfo(robotId, refresh: refresh);
        if (userInfo != null) {
          userInfo.displayName = userInfo.displayName ?? '<${userInfo.userId}>';
          contactList.add(UIContactInfo("AI", false, userInfo));
        }
      }
    }

    if (Config.FILE_TRANSFER_ID.isNotEmpty) {
      var userInfo =
          await Imclient.getUserInfo(Config.FILE_TRANSFER_ID, refresh: refresh);
      if (userInfo != null) {
        userInfo.displayName = userInfo.displayName ?? '<${userInfo.userId}>';
        contactList.add(
            UIContactInfo(_categoryOf(userInfo.displayName!), false, userInfo));
      }
    }

    _sortByCategoryThenName(contactList);

    var lastCategory = "";
    for (var contactInfo in contactList) {
      if (contactInfo.category == lastCategory) {
        contactInfo.showCategory = false;
      } else {
        contactInfo.showCategory = true;
      }
      lastCategory = contactInfo.category;
    }

    // 显示内容没变就复用旧列表:UserInfoUpdatedEvent 常带着无变化的数据批量到达,
    // 换新实例会让联系人页重算全量布局并重建所有可见行。
    if (_sameAsCurrent(contactList)) {
      return;
    }

    _contactList = contactList;
    _contactUserIds = {for (final c in contactList) c.userInfo.userId};
    notifyListeners();
  }

  /// 排序:星标 -> AI 机器人 -> 分类字母,同分类按显示名。
  /// 分类先映射成 int,避免比较器里反复做字符串相等判断
  /// (两万条约 29 万次比较,原实现每次比较最多要做 6 次字符串比较)。
  static void _sortByCategoryThenName(List<UIContactInfo> contactList) {
    int rankOf(String category) {
      if (category == "☆") return 0;
      if (category == "AI") return 1;
      return 2;
    }

    final sortable = contactList
        .map((info) => (
              rank: rankOf(info.category),
              category: info.category,
              name: info.userInfo.displayName ?? '',
              info: info,
            ))
        .toList();
    sortable.sort((a, b) {
      if (a.rank != b.rank) return a.rank - b.rank;
      final byCategory = a.category.compareTo(b.category);
      if (byCategory != 0) return byCategory;
      return a.name.compareTo(b.name);
    });
    for (int i = 0; i < sortable.length; i++) {
      contactList[i] = sortable[i].info;
    }
  }

  /// 新算出的列表在 UI 上是否与当前列表完全等价。
  bool _sameAsCurrent(List<UIContactInfo> contactList) {
    if (_contactList.length != contactList.length) return false;
    for (int i = 0; i < contactList.length; i++) {
      final a = _contactList[i];
      final b = contactList[i];
      if (a.category != b.category || a.showCategory != b.showCategory) {
        return false;
      }
      final au = a.userInfo;
      final bu = b.userInfo;
      if (au.userId != bu.userId ||
          au.updateDt != bu.updateDt ||
          au.displayName != bu.displayName ||
          au.friendAlias != bu.friendAlias ||
          au.portrait != bu.portrait) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    super.dispose();
    _debounceTimer?.cancel();
    _friendUpdatedSubscription.cancel();
    _friendRequestUpdatedSubscription.cancel();
    _userInfoUpdatedSubscription.cancel();
    _clearFriendRequestSubscription.cancel();
    _connectionStatusSubscription.cancel();
    _userSettingUpdatedSubscription.cancel();
  }
}
