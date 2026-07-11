import 'package:flutter/material.dart';
import 'package:imclient/model/user_online_state.dart';
import 'package:chat/utils/online_state_cache.dart';

/// 在线状态构建器。
///
/// 封装「加载初始状态 + 监听 [OnlineStateCache] 变化」的样板代码。
/// 首次构建时同步调用 [OnlineStateCache.loadState] 并将结果交给 [builder]；
/// 当 [UserOnlineStateUpdatedEvent] 触发缓存更新时，自动重建。
class OnlineStateBuilder extends StatefulWidget {
  final String userId;
  final Widget Function(BuildContext context, UserOnlineState? state) builder;

  const OnlineStateBuilder({
    super.key,
    required this.userId,
    required this.builder,
  });

  @override
  State<OnlineStateBuilder> createState() => _OnlineStateBuilderState();
}

class _OnlineStateBuilderState extends State<OnlineStateBuilder> {
  UserOnlineState? _state;

  @override
  void initState() {
    super.initState();
    _state = OnlineStateCache.instance.loadState(widget.userId);
    OnlineStateCache.instance.addListener(_onOnlineStateChanged);
  }

  @override
  void didUpdateWidget(covariant OnlineStateBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _state = OnlineStateCache.instance.loadState(widget.userId);
    }
  }

  @override
  void dispose() {
    OnlineStateCache.instance.removeListener(_onOnlineStateChanged);
    super.dispose();
  }

  void _onOnlineStateChanged() {
    if (!mounted) return;
    final updated = OnlineStateCache.instance.stateOf(widget.userId);
    if (_state != updated) {
      setState(() => _state = updated);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _state);
}
