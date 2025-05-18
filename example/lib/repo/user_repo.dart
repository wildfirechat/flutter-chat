import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';

class UserRepo {
  static final Map<String, UserInfo> _userMap = {};
  static final Map<String, Map<String, UserInfo>> _groupUserMap = {};
  static StreamSubscription? _userInfoUpdateSubscription;
  static StreamSubscription? _groupMembersUpdateSubscription;

  static void init() {
    _userInfoUpdateSubscription?.cancel();
    _userInfoUpdateSubscription = Imclient.IMEventBus.on<UserInfoUpdatedEvent>().listen((event) {
      final List<UserInfo> updatedUsers = event.userInfos;

      for (var userInfo in updatedUsers) {
        if (userInfo.updateDt > 0) {
          _userMap[userInfo.userId] = userInfo;

          _groupUserMap.forEach((groupId, groupCache) {
            if (groupCache.containsKey(userInfo.userId)) {
              groupCache.remove(userInfo.userId);
            }
          });
        }
      }
    });

    _groupMembersUpdateSubscription?.cancel();
    _groupMembersUpdateSubscription = Imclient.IMEventBus.on<GroupMembersUpdatedEvent>().listen((event) {
      final String groupId = event.groupId;
      final List<GroupMember> updatedMembers = event.members;

      var groupUserCache = _groupUserMap[groupId];
      if (groupUserCache != null) {
        for (var member in updatedMembers) {
          groupUserCache.remove(member.memberId);
        }
      }
    });
  }

  static void clear() {
    _userMap.clear();
    _groupUserMap.clear();
  }

  static void dispose() {
    clear();
    _userInfoUpdateSubscription?.cancel();
    _userInfoUpdateSubscription = null;
    _groupMembersUpdateSubscription?.cancel();
    _groupMembersUpdateSubscription = null;
  }

  // todo
  // get in memory
  // load in db, or remote

  static Future<UserInfo?> getUserInfo(String userId, {String? groupId}) async {
    var map = groupId != null ? _groupUserMap[groupId] : _userMap;
    if (groupId != null && map == null) {
      map = {};
      _groupUserMap[groupId] = map;
    }
    var info = map?[userId];
    if (info == null) {
      info = await Imclient.getUserInfo(userId, groupId: groupId);
      if (info != null && info.updateDt > 0) {
        map?[userId] = info;
      }
    }
    return info;
  }

  static Future<List<UserInfo>> getUserInfos(List<String> userIds, {String? groupId}) async {
    List<UserInfo> userInfos = [];
    userInfos = await Imclient.getUserInfos(userIds, groupId: groupId);
    var map = groupId != null ? _groupUserMap[groupId] : _userMap;
    if (groupId != null && map == null) {
      map = {};
      _groupUserMap[groupId] = map;
    }
    for (var u in userInfos) {
      if (u.updateDt > 0) {
        map?[u.userId] = u;
      }
    }
    return userInfos;
  }
}
