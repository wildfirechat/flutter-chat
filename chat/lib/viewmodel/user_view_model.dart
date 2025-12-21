import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/repo/user_repo.dart';

class UserViewModel extends ChangeNotifier {
  late StreamSubscription? _userInfoUpdateSubscription;
  late StreamSubscription? _groupMembersUpdateSubscription;

  UserViewModel() {
    _userInfoUpdateSubscription = Imclient.IMEventBus.on<UserInfoUpdatedEvent>().listen((event) {
      final List<UserInfo> updatedUsers = event.userInfos;

      debugPrint('userInfo updated ${updatedUsers.length}');
      UserRepo.updateUserInfos(updatedUsers);
      notifyListeners();
    });

    // _groupMembersUpdateSubscription?.cancel();
    _groupMembersUpdateSubscription = Imclient.IMEventBus.on<GroupMembersUpdatedEvent>().listen((event) {
      debugPrint('groupMembers updated ${event.groupId} ${event.members}');
      final String groupId = event.groupId;
      final List<GroupMember> updatedMembers = event.members;
      UserRepo.updateGroupUserInfos(groupId, updatedMembers);
      notifyListeners();
    });
  }

  final Set<String> _fetchingUserIds = {};

  UserInfo? getUserInfo(String userId, {String? groupId}) {
    // debugPrint('getUserInfo $userId groupId $groupId');
    var info = UserRepo.getUserInfo(userId, groupId: groupId);
    if (info == null) {
      String key = groupId != null ? "$userId@$groupId" : userId;
      if (!_fetchingUserIds.contains(key)) {
        _fetchingUserIds.add(key);
        Imclient.getUserInfo(userId, groupId: groupId).then((info) {
          _fetchingUserIds.remove(key);
          if (info != null) {
            UserRepo.putUserInfo(info, groupId: groupId);
            notifyListeners();
          }
        });
      }
    }
    return info;
  }

  @override
  void dispose() {
    super.dispose();
    _userInfoUpdateSubscription?.cancel();
    _userInfoUpdateSubscription = null;
    _groupMembersUpdateSubscription?.cancel();
    _groupMembersUpdateSubscription = null;
  }
}
