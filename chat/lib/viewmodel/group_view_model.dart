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
      // 桌面端 SDK 的成员变更回调只回传 groupId,成员列表要上层自己拉
      // (见 imclient_ffi_channel 的 groupMemberUpdated 分支);移动端直接带回来。
      // 不补这一拉,桌面端所有群成员变更都会被当成空列表丢掉。
      if (event.members.isEmpty) {
        Imclient.getGroupMembers(event.groupId).then((members) {
          _loadAndNotifyGroupMemberUserInfos(event.groupId, members);
        });
      } else {
        _loadAndNotifyGroupMemberUserInfos(event.groupId, event.members);
      }
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
        // 没头像的群多半是「成员还没到本地,拼接头像没算出来」,把成员拉回来触发
        // 一次补算(见 _refreshComposedPortraitIfNeeded)。已经有头像的群不动,
        // 不会给整个会话列表平白多出一轮成员查询。
        if (info.portrait == null || info.portrait!.isEmpty) {
          _ensureGroupMembersLoaded(info.target);
        }
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

  /// 拉一次群成员(本地没有时 SDK 会异步从服务器补),每个群一次,与
  /// [getGroupMemberUserInfos] 共用同一个去重集合。
  void _ensureGroupMembersLoaded(String groupId) {
    if (!_fetchedGroupMemberIds.add(groupId)) return;
    Imclient.getGroupMembers(groupId).then((members) {
      _loadAndNotifyGroupMemberUserInfos(groupId, members);
    });
  }

  _loadAndNotifyGroupMemberUserInfos(
      String groupId, List<GroupMember> members) {
    if (members.isNotEmpty) {
      var memberIds = members.map((e) => e.memberId).toList();
      Imclient.getUserInfos(memberIds, groupId: groupId).then((userInfos) {
        UserRepo.putGroupMemberUserInfos(groupId, userInfos);
        notifyListeners();
        _refreshComposedPortraitIfNeeded(groupId);
      });
    }
  }

  /// 群没自己设头像时,头像是 imclient 转换 GroupInfo 那一刻,拿**本地已有的**前 9
  /// 个成员的用户信息拼出来的一个地址(见 WFPortraitProvider.groupDefaultPortrait),
  /// 本地没有成员就拼不出来,portrait 为空。
  ///
  /// 在别的端建的群刚同步过来时正是这种情况:群信息先到,成员列表还没拉到本地,
  /// 那一次转换拼不出东西;而这份没有头像的 GroupInfo 会被 [GroupRepo] 一直缓存
  /// (只有 updateDt 变了才会换),成员随后到齐也不会再算一次 —— 于是这个群的头像
  /// 就一直是空的(桌面端上尤其明显,自己建的群有成员所以正常,手机上建的群没有)。
  /// 这里在成员用户信息到位后补算一次。
  Future<void> _refreshComposedPortraitIfNeeded(String groupId) async {
    final cached = GroupRepo.peekGroupInfo(groupId);
    // 群信息本身还没到,等它自己那条路走完,那次转换就会把头像带上
    if (cached == null || cached.updateDt == 0) return;
    // 已经有头像(自定义的或上一次补算出来的)就不用再算,这一条同时挡住了重复补算
    if (cached.portrait != null && cached.portrait!.isNotEmpty) return;

    final refreshed = await Imclient.getGroupInfo(groupId);
    if (_disposed || refreshed == null || refreshed.updateDt == 0) return;
    if (refreshed.portrait == null || refreshed.portrait!.isEmpty) return;
    GroupRepo.putGroupInfo(refreshed);
    notifyListeners();
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
