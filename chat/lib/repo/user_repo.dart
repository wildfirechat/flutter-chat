import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';

// user cache, only cache
mixin UserRepo {
  static final Map<String, UserInfo> _userMap = {};
  static final Map<String, UserInfo> _friendUserMap = {};
  static final Map<String, Map<String, UserInfo>> _groupUserMap = {};

  static void clear() {
    _userMap.clear();
    _friendUserMap.clear();
    _groupUserMap.clear();
  }

  /// 单次 getUserInfos 的条数上限。
  ///
  /// ImclientPlugin 的 method call 跑在 Android 主线程上,而 Flutter 的 vsync
  /// 同样由主线程的 Choreographer 发出 —— 一次两万人的 getUserInfos 会把主线程
  /// 占住好几秒,期间整个 App 一帧都出不来。切成小片后,片与片之间主线程的
  /// Looper 能插进 vsync 回调,界面就还能动。
  static const int _userInfoChunkSize = 200;

  static Future<List<UserInfo>> getFriendUserInfos(
      {bool refresh = false}) async {
    if (!refresh && _friendUserMap.isNotEmpty) {
      return _friendUserMap.values.toList();
    }
    var friends = await Imclient.getMyFriendList(refresh: refresh);

    // 只补拉缓存里没有的。refresh 的语义是「重新同步好友关系」,
    // 已经在内存里的用户信息由 UserInfoUpdatedEvent 负责更新,
    // 不必每次进联系人页都把两万条重新搬一遍。
    final missing =
        friends.where((userId) => !_friendUserMap.containsKey(userId)).toList();
    for (int start = 0; start < missing.length; start += _userInfoChunkSize) {
      final end = min(start + _userInfoChunkSize, missing.length);
      final userInfos =
          await Imclient.getUserInfos(missing.sublist(start, end));
      for (var user in userInfos) {
        _friendUserMap[user.userId] = user;
        _userMap.remove(user.userId);
      }
    }

    // 已解除好友关系的要从缓存里清掉,否则会一直留在联系人列表上。
    final friendIds = friends.toSet();
    _friendUserMap.removeWhere((userId, _) => !friendIds.contains(userId));

    debugPrint(
        'getFriendUserInfos ${_friendUserMap.length} (fetched ${missing.length})');
    return _friendUserMap.values.toList();
  }

  static UserInfo getUserInfo(String userId, {String? groupId}) {
    var targetMap = _targetMap(userId, groupId: groupId);
    var userInfo = targetMap[userId];
    if (userInfo == null) {
      // for reactive
      userInfo = UserInfo(userId, updateDt: 0);
      targetMap[userId] = userInfo;
    }
    return userInfo;
  }

  static List<UserInfo>? getGroupMemberUserInfos(String groupId) {
    return _groupUserMap[groupId]?.values.toList();
  }

  static void putGroupMemberUserInfos(
      String groupId, List<UserInfo> userInfos) {
    var map = _groupUserMap[groupId];
    if (map == null) {
      map = {};
      _groupUserMap[groupId] = map;
    }
    for (var userInfo in userInfos) {
      map[userInfo.userId] = userInfo;
    }
  }

  static void putUserInfo(UserInfo userInfo, {String? groupId}) {
    var targetMap = _targetMap(userInfo.userId, groupId: groupId);
    targetMap[userInfo.userId] = userInfo;
  }

  static void updateGroupUserInfos(String groupId, List<GroupMember> members) {
    for (var member in members) {
      var map = _targetMap(member.memberId, groupId: groupId);
      map[member.memberId]?.groupAlias = member.alias;
    }
  }

  static void updateUserInfos(List<UserInfo> userInfos) {
    for (var userInfo in userInfos) {
      if (_friendUserMap.containsKey(userInfo.userId)) {
        _friendUserMap[userInfo.userId] = userInfo;
      } else {
        _userMap[userInfo.userId] = userInfo;
      }
      _groupUserMap.forEach((groupId, groupCache) {
        var oldGroupUser = groupCache[userInfo.userId];
        if (oldGroupUser != null) {
          UserInfo newGroupUser = UserInfo(userInfo.userId);
          newGroupUser.userId = userInfo.userId;
          newGroupUser.name = userInfo.name;
          newGroupUser.displayName = userInfo.displayName;
          newGroupUser.gender = userInfo.gender;
          newGroupUser.portrait = userInfo.portrait;
          newGroupUser.mobile = userInfo.mobile;
          newGroupUser.email = userInfo.email;
          newGroupUser.address = userInfo.address;
          newGroupUser.company = userInfo.company;
          newGroupUser.social = userInfo.social;
          newGroupUser.extra = userInfo.extra;
          newGroupUser.friendAlias = userInfo.friendAlias;
          newGroupUser.updateDt = userInfo.updateDt;
          newGroupUser.type = userInfo.type;
          newGroupUser.deleted = userInfo.deleted;
          newGroupUser.groupAlias = oldGroupUser.groupAlias;
          groupCache[userInfo.userId] = newGroupUser;
        }
      });
    }
  }

  // static Future<List<UserInfo>> getUserInfos(List<String> userIds, {String? groupId}) async {
  //   List<UserInfo> userInfos = [];
  //   userInfos = await Imclient.getUserInfos(userIds, groupId: groupId);
  //   var map = groupId != null ? _groupUserMap[groupId] : _userMap;
  //   if (groupId != null && map == null) {
  //     map = {};
  //     _groupUserMap[groupId] = map;
  //   }
  //   for (var u in userInfos) {
  //     if (u.updateDt > 0) {
  //       map?[u.userId] = u;
  //     }
  //   }
  //   return userInfos;
  // }

  static Map<String, UserInfo> _targetMap(String userId, {String? groupId}) {
    Map<String, UserInfo> target;
    if (groupId != null) {
      var map = _groupUserMap[groupId];
      if (map == null) {
        map = {};
        _groupUserMap[groupId] = map;
      }
      target = map;
    } else {
      if (_friendUserMap.containsKey(userId)) {
        target = _friendUserMap;
      } else {
        target = _userMap;
      }
    }
    return target;
  }
}
