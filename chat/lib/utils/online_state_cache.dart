import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_online_state.dart';

/// 用户在线状态缓存，对齐 iOS WFCU/WFCC 行为。
///
/// - 监听 [UserOnlineStateUpdatedEvent] 更新内存缓存。
/// - 提供同步查询能力；UI 格式化请使用 [OnlineStateFormatter]。
class OnlineStateCache extends ChangeNotifier {
  OnlineStateCache._() {
    _subscription =
        Imclient.IMEventBus.on<UserOnlineStateUpdatedEvent>().listen((event) {
      _updateStates(event.onlineInfos);
    });
  }

  static final OnlineStateCache _instance = OnlineStateCache._();
  static OnlineStateCache get instance => _instance;

  StreamSubscription? _subscription;
  final Map<String, UserOnlineState> _states = {};
  bool? _enabled;

  /// 确保已查询过服务端是否开启在线状态功能。
  Future<bool> get isEnabled async {
    await _ensureEnabled();
    return _enabled ?? false;
  }

  /// 同步获取缓存中的在线状态（可能为 null）。
  UserOnlineState? stateOf(String userId) => _states[userId];

  /// 从服务端拉取指定用户的在线状态并写入缓存。
  ///
  /// 桌面端 [Imclient.getUserOnlineState] 返回 null，这里回退到本缓存，
  /// 保证事件已到达时能同步取到状态。
  UserOnlineState? loadState(String userId) {
    final state = Imclient.getUserOnlineState(userId) ?? _states[userId];
    if (state != null) {
      _states[userId] = state;
    }
    return state;
  }

  /// 清空缓存，切换账号时调用。
  void clear() {
    _states.clear();
    _enabled = null;
    notifyListeners();
  }

  Future<void> _ensureEnabled() async {
    if (_enabled != null) return;
    try {
      _enabled = await Imclient.isEnableUserOnlineState();
    } catch (e) {
      _enabled = false;
    }
  }

  void _updateStates(List<UserOnlineState> states) {
    if (states.isEmpty) return;
    var changed = false;
    for (final state in states) {
      if (state.userId.isNotEmpty) {
        _states[state.userId] = state;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
