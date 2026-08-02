import 'dart:async';

import 'package:flutter/foundation.dart';

typedef BatchFetch<K> = Future<void> Function(List<K> keys);

/// 把「列表逐行发现的缺失数据」按固定窗口、限量地合并成批量查询。
///
/// **为什么三条约束一条都不能少** —— `ImclientPlugin.onMethodCall` 跑在 Android
/// 主线程上,而 Flutter 的 vsync 也是主线程 Choreographer 发出来的,所以一次耗时的
/// 原生查询会直接让整个 App 停止出帧:
///
/// 1. **窗口固定,不因新请求重置。** 用防抖(每来一个 id 就把定时器推后)会导致
///    滚动期间一个都不发,手一停把攒下的上万个 id 一次性甩出去 —— 比不批量还糟。
/// 2. **单批有上限。** 批量的收益是省掉 N 次跨进程往返,不是把 N 条查询压成一次
///    长阻塞;超过上限的留到下一个窗口。
/// 3. **队列有上限且后进先出。** 飞速滚动会攒下大量已经滑出视野的 id,它们不该
///    排在当前屏幕内容前面;超量的直接丢弃,下次进入视野时会重新登记。
class BatchLoader<K> {
  BatchLoader({
    required this.fetch,
    this.window = const Duration(milliseconds: 80),
    this.batchSize = 24,
    this.maxPending = 240,
    this.debugLabel = 'BatchLoader',
  });

  final BatchFetch<K> fetch;

  /// 攒批窗口。从第一个请求进来开始计时,期间的新请求不会把它推后。
  final Duration window;

  /// 单次交给 [fetch] 的最大条数。
  final int batchSize;

  /// 待查队列上限,超出后丢弃最早登记的。
  final int maxPending;

  final String debugLabel;

  /// 待查队列,队尾是最新登记的(后进先出)。
  final List<K> _pending = [];
  final Set<K> _pendingSet = {};

  /// 已经发起过查询的 key。只有 [fetch] 抛异常才会移除 —— 查不到就重查会形成
  /// 「重建 -> 查询 -> 通知 -> 重建」的风暴。
  final Set<K> _requested = {};

  Timer? _timer;
  bool _running = false;

  /// 登记一个待查 key。已经查过或已在队列里则忽略。
  void request(K key) {
    if (_requested.contains(key) || _pendingSet.contains(key)) return;
    _pending.add(key);
    _pendingSet.add(key);
    while (_pending.length > maxPending) {
      _pendingSet.remove(_pending.removeAt(0));
    }
    _schedule();
  }

  void _schedule() {
    if (_timer?.isActive ?? false) return;
    _timer = Timer(window, _drain);
  }

  Future<void> _drain() async {
    if (_running) {
      _schedule();
      return;
    }
    if (_pending.isEmpty) return;

    _running = true;
    final batch = <K>[];
    try {
      // 后进先出:最近登记的最可能还在屏幕上。
      while (batch.length < batchSize && _pending.isNotEmpty) {
        final key = _pending.removeLast();
        _pendingSet.remove(key);
        _requested.add(key);
        batch.add(key);
      }
      await fetch(batch);
    } catch (e) {
      // 失败允许下次重建时重新登记
      _requested.removeAll(batch);
      debugPrint('$debugLabel batch failed: $e');
    } finally {
      _running = false;
      if (_pending.isNotEmpty) _schedule();
    }
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
    _pendingSet.clear();
    _requested.clear();
  }
}
