import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/repo/group_repo.dart';
import 'package:chat/repo/user_repo.dart';
import 'package:chat/utils/batch_loader.dart';

class GroupViewModel extends ChangeNotifier {
  late StreamSubscription<GroupInfoUpdatedEvent> _groupInfoUpdatedSubscription;
  late StreamSubscription<GroupMembersUpdatedEvent>
      _groupMembersUpdatedSubscription;

  GroupViewModel() {
    _groupInfoUpdatedSubscription =
        Imclient.IMEventBus.on<GroupInfoUpdatedEvent>().listen((event) {
      GroupRepo.updateGroupInfos(event.groupInfos);
      notifyListeners();
    });
    _groupMembersUpdatedSubscription =
        Imclient.IMEventBus.on<GroupMembersUpdatedEvent>().listen((event) {
      _loadAndNotifyGroupMemberUserInfos(event.groupId, event.members);
    });
  }

  void reset() {
    _loader.clear();
    _fetchedGroupMemberIds.clear();
    GroupRepo.clear();
    notifyListeners();
  }

  /// 同 [UserViewModel]:缺失的群信息按固定窗口限量成批查询,整批只通知一次。
  /// 单批必须小 —— ImclientPlugin 的 method call 跑在 Android 主线程上。
  late final BatchLoader<String> _loader = BatchLoader<String>(
    fetch: _fetchBatch,
    debugLabel: 'GroupViewModel',
  );

  // 已发起过成员获取（获取中或已获取）的群：build 路径每次重建都会调
  // getGroupMemberUserInfos，每个 groupId 只允许走一次 DB 查询，
  // 后续变更由 GroupMembersUpdatedEvent 驱动刷新。
  final Set<String> _fetchedGroupMemberIds = {};

  GroupInfo getGroupInfo(String groupId) {
    var groupInfo = GroupRepo.getGroupInfo(groupId);
    if (groupInfo.updateDt == 0) {
      _loader.request(groupId);
    }
    return groupInfo;
  }

  Future<void> _fetchBatch(List<String> groupIds) async {
    final infos = await Imclient.getGroupInfos(groupIds);
    bool changed = false;
    for (final info in infos) {
      if (info.updateDt > 0) {
        GroupRepo.putGroupInfo(info);
        changed = true;
      }
    }
    if (changed && !_disposed) notifyListeners();
  }

  bool _disposed = false;

  List<UserInfo>? getGroupMemberUserInfos(String groupId) {
    var memberUserInfos = UserRepo.getGroupMemberUserInfos(groupId);
    // 同一 groupId 只查一次，避免 build 重建反复发 DB 查询
    if (_fetchedGroupMemberIds.add(groupId)) {
      Imclient.getGroupMembers(groupId).then((members) {
        if (memberUserInfos == null ||
            members.length != memberUserInfos.length) {
          _loadAndNotifyGroupMemberUserInfos(groupId, members);
        }
      });
    }
    return memberUserInfos;
  }

  _loadAndNotifyGroupMemberUserInfos(
      String groupId, List<GroupMember> members) {
    if (members.isNotEmpty) {
      var memberIds = members.map((e) => e.memberId).toList();
      Imclient.getUserInfos(memberIds, groupId: groupId).then((userInfos) {
        UserRepo.putGroupMemberUserInfos(groupId, userInfos);
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loader.clear();
    _groupInfoUpdatedSubscription.cancel();
    _groupMembersUpdatedSubscription.cancel();
    super.dispose();
  }
}
