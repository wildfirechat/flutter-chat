import 'dart:async';

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
    _groupUserMap.clear();
  }

  static Future<List<UserInfo>> loadFriendUserInfos({bool refresh = false}) async {
    if (!refresh && _friendUserMap.isNotEmpty) {
      return _friendUserMap.values.toList();
    }
    var friends = await Imclient.getMyFriendList(refresh: refresh);
    var userInfos = await Imclient.getUserInfos(friends);
    for (var user in userInfos) {
      _friendUserMap[user.userId] = user;
      _userMap.remove(user.userId);
    }
    debugPrint('loadFriendUserInfos ${userInfos.length}');
    return userInfos;
  }

  static UserInfo? getUserInfo(String userId, {String? groupId}) {
    var targetMap = _targetMap(userId, groupId: groupId);
    return targetMap[userId];
  }

  static List<UserInfo>? getGroupMemberUserInfos(String groupId) {
    return _groupUserMap[groupId]?.values.toList();
  }

  static void putGroupMemberUserInfos(String groupId, List<UserInfo> userInfos) {
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
          oldGroupUser
            ..displayName = userInfo.displayName
            ..name = userInfo.name
            ..displayName = userInfo.displayName
            ..gender = userInfo.gender
            ..portrait = userInfo.portrait
            ..mobile = userInfo.mobile
            ..email = userInfo.email
            ..address = userInfo.address
            ..company = userInfo.company
            ..social = userInfo.social
            ..extra = userInfo.extra
            ..friendAlias = userInfo.friendAlias
            ..updateDt = userInfo.updateDt
            ..type = userInfo.type
            ..deleted = userInfo.deleted;
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
