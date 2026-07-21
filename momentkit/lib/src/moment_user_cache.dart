import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';

/// 朋友圈场景的用户信息缓存。
///
/// 头像/昵称渲染高频且重复，这里统一走 [Imclient.getUserInfo]（SDK 自身有
/// 本地数据库缓存）并做内存级缓存 + 变更通知，避免列表滚动时反复查询。
class MomentUserCache extends ChangeNotifier {
  MomentUserCache._();

  static final MomentUserCache instance = MomentUserCache._();

  final Map<String, UserInfo> _cache = {};
  final Set<String> _loading = {};

  /// 同步取缓存；未命中时触发异步加载并在完成后 [notifyListeners]。
  UserInfo? operator [](String userId) {
    if (userId.isEmpty) return null;
    final cached = _cache[userId];
    if (cached != null) return cached;
    _load(userId);
    return null;
  }

  void _load(String userId) {
    if (_loading.contains(userId)) return;
    _loading.add(userId);
    Imclient.getUserInfo(userId).then((info) {
      if (info != null) {
        _cache[userId] = info;
        notifyListeners();
      }
    }).catchError((_) {}).whenComplete(() => _loading.remove(userId));
  }

  /// 强制刷新某个用户。
  Future<void> refresh(String userId) async {
    final info = await Imclient.getUserInfo(userId, refresh: true);
    if (info != null) {
      _cache[userId] = info;
      notifyListeners();
    }
  }

  /// 展示名：备注 > 昵称 > 名字 > userId，与通讯录展示规则一致。
  String displayNameOf(String userId) {
    final info = this[userId];
    if (info == null) return userId;
    if ((info.friendAlias ?? '').isNotEmpty) return info.friendAlias!;
    if ((info.displayName ?? '').isNotEmpty) return info.displayName!;
    if (info.name.isNotEmpty) return info.name;
    return userId;
  }

  String portraitOf(String userId) => this[userId]?.portrait ?? '';

  void clear() {
    _cache.clear();
    _loading.clear();
  }
}
