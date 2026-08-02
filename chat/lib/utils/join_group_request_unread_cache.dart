import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';

/// 群会话行上「N 条新入群申请」角标的未读数缓存。
///
/// 为什么需要它:`Imclient.getJoinGroupRequestUnread` 在 Android 上是
/// 「平台通道 → ChatManager → AIDL 跨进程 → ClientService」的一整套往返。
/// 原实现让每个群会话 cell 在 initState 里各发一次,并且每个 cell 都单独订阅
/// [JoinGroupRequestUpdatedEvent] —— 上万会话滚动时每滑进一行就打一发 IPC,
/// 主线程被回调和 setState 淹没。(官方 Android UIKit 的
/// GroupConversationViewHolder 里这行调用同样是注释掉的。)
///
/// 这里的做法:cell 只登记「我关心哪个群」,查询统一延后到滚动停下之后再发,
/// 并且只发给仍在视野里的群;结果按 groupId 缓存,滚回去不再重复查询。
class JoinGroupRequestUnreadCache {
  JoinGroupRequestUnreadCache._() {
    _subscription = Imclient.IMEventBus
        .on<JoinGroupRequestUpdatedEvent>()
        .listen((_) => _invalidate());
  }

  static final JoinGroupRequestUnreadCache instance =
      JoinGroupRequestUnreadCache._();

  /// 滚动停止多久后才真正发查询。快速滑过的行不该产生任何 IPC。
  static const Duration _flushDelay = Duration(milliseconds: 300);

  StreamSubscription? _subscription;

  /// groupId -> 未读数。滚出视野后仍然保留,避免来回滚动反复查询。
  final Map<String, int> _counts = {};

  /// 仍在视野里(有 cell 在看)的群。
  final Map<String, _UnreadWatch> _watches = {};

  /// 待查询的 groupId。
  final Set<String> _stale = {};

  Timer? _flushTimer;
  bool _flushing = false;

  /// 订阅 [groupId] 的入群申请未读数。调用方必须在销毁时调用 [release]。
  ValueListenable<int> watch(String groupId) {
    var watch = _watches[groupId];
    if (watch == null) {
      watch = _UnreadWatch(_counts[groupId] ?? 0);
      _watches[groupId] = watch;
    }
    watch.refCount++;

    if (!_counts.containsKey(groupId)) {
      _stale.add(groupId);
      _scheduleFlush();
    }
    return watch.notifier;
  }

  void release(String groupId) {
    final watch = _watches[groupId];
    if (watch == null) return;
    if (--watch.refCount <= 0) {
      _watches.remove(groupId);
      watch.notifier.dispose();
    }
  }

  /// 退出登录时清空。
  void clear() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _stale.clear();
    _counts.clear();
    for (final watch in _watches.values) {
      watch.notifier.value = 0;
    }
  }

  void _invalidate() {
    _counts.clear();
    // 只重查还在视野里的群,其余等下次滚进视野时按需查。
    _stale
      ..clear()
      ..addAll(_watches.keys);
    if (_stale.isNotEmpty) _scheduleFlush();
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDelay, _flush);
  }

  Future<void> _flush() async {
    if (_flushing) {
      _scheduleFlush();
      return;
    }
    _flushing = true;
    try {
      // 快速滚动会在 _stale 里积压大量已经滑过去的 groupId,这里全部丢掉。
      final targets = _stale.where(_watches.containsKey).toList();
      _stale.clear();
      for (final groupId in targets) {
        final watch = _watches[groupId];
        if (watch == null) continue; // 查询期间滚出了视野
        try {
          final count =
              await Imclient.getJoinGroupRequestUnread(groupId: groupId);
          _counts[groupId] = count;
          _watches[groupId]?.notifier.value = count;
        } catch (e) {
          // 查询失败不写缓存,下次进入视野时会重试
          debugPrint('getJoinGroupRequestUnread failed for $groupId: $e');
        }
      }
    } finally {
      _flushing = false;
    }
  }

  @visibleForTesting
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _flushTimer?.cancel();
  }
}

class _UnreadWatch {
  _UnreadWatch(int initial) : notifier = ValueNotifier<int>(initial);

  final ValueNotifier<int> notifier;
  int refCount = 0;
}
