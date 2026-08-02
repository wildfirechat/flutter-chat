import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/repo/user_repo.dart';
import 'package:chat/utils/batch_loader.dart';

import '../mesh/mesh_cache.dart';

/// 用户信息的查询键。群成员信息按群隔离(群昵称不同),所以要带上 groupId。
@immutable
class _UserKey {
  const _UserKey(this.userId, this.groupId);

  final String userId;
  final String? groupId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UserKey && userId == other.userId && groupId == other.groupId;

  @override
  int get hashCode => Object.hash(userId, groupId);
}

class UserViewModel extends ChangeNotifier {
  late StreamSubscription? _userInfoUpdateSubscription;
  late StreamSubscription? _groupMembersUpdateSubscription;
  late Listenable? _meshCacheListener;

  UserViewModel() {
    _userInfoUpdateSubscription =
        Imclient.IMEventBus.on<UserInfoUpdatedEvent>().listen((event) {
      final List<UserInfo> updatedUsers = event.userInfos;

      debugPrint('userInfo updated ${updatedUsers.length}');
      UserRepo.updateUserInfos(updatedUsers);
      notifyListeners();
    });

    // _groupMembersUpdateSubscription?.cancel();
    _groupMembersUpdateSubscription =
        Imclient.IMEventBus.on<GroupMembersUpdatedEvent>().listen((event) {
      debugPrint('groupMembers updated ${event.groupId} ${event.members}');
      final String groupId = event.groupId;
      final List<GroupMember> updatedMembers = event.members;
      UserRepo.updateGroupUserInfos(groupId, updatedMembers);
      notifyListeners();
    });

    // 外部单位/域名称变化时，依赖用户显示名的 widget 需要重绘
    _meshCacheListener = MeshCache.instance;
    _meshCacheListener?.addListener(notifyListeners);
  }

  void reset() {
    _loader.clear();
    UserRepo.clear();
    notifyListeners();
  }

  /// 缺失的用户信息按固定窗口限量成批查询。约束与代价见 [BatchLoader] ——
  /// 关键是「单批必须小」:ImclientPlugin 的 method call 跑在 Android 主线程,
  /// 一次大批量查询会把 Flutter 的 vsync 一起堵死。
  late final BatchLoader<_UserKey> _loader = BatchLoader<_UserKey>(
    fetch: _fetchBatch,
    debugLabel: 'UserViewModel',
  );

  UserInfo getUserInfo(String userId, {String? groupId}) {
    var info = UserRepo.getUserInfo(userId, groupId: groupId);
    if (info.updateDt == 0) {
      _loader.request(_UserKey(userId, groupId));
    }
    return info;
  }

  Future<void> _fetchBatch(List<_UserKey> keys) async {
    // 同一批里可能混着不同群的成员信息,按 groupId 分桶,每桶一次查询。
    final buckets = <String?, List<String>>{};
    for (final key in keys) {
      (buckets[key.groupId] ??= <String>[]).add(key.userId);
    }

    // 本地查不到的用户不再逐个 getUserInfo 兜底:官方 iOS/Android UIKit 的列表页
    // 同样只用批量接口(两端底层都只是转发 MessageDB::getUserInfos),缺失的用户由
    // SDK 自己补拉,结果经 UserInfoUpdatedEvent 回来。逐个兜底在冷库场景下会退化成
    // 每个窗口几十次阻塞主线程的调用。
    bool changed = false;
    for (final entry in buckets.entries) {
      final groupId = entry.key;
      final infos = await Imclient.getUserInfos(entry.value, groupId: groupId);
      for (final info in infos) {
        if (info.updateDt > 0) {
          UserRepo.putUserInfo(info, groupId: groupId);
          changed = true;
        }
      }
    }

    // 整批只通知一次,而不是每个用户一次 —— 每次 notify 都会让列表里所有
    // Selector 重估一遍。
    if (changed && !_disposed) notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _loader.clear();
    _userInfoUpdateSubscription?.cancel();
    _userInfoUpdateSubscription = null;
    _groupMembersUpdateSubscription?.cancel();
    _groupMembersUpdateSubscription = null;
    _meshCacheListener?.removeListener(notifyListeners);
    _meshCacheListener = null;
    super.dispose();
  }
}
