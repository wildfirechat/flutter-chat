import 'package:flutter/material.dart';

/// 媒体消息缩略图锚点:按 messageId 登记自身,供预览拖拽退出时把大图
/// 缩回到对应气泡(参考微信)。
///
/// 用 State 实例登记而不是 GlobalKey:同一条消息在叠开的多个会话页里
/// 重复渲染时不会触发 GlobalKey 冲突,取最后登记(最上层)的那个。
class MediaCellAnchor extends StatefulWidget {
  final int messageId;
  final Widget child;

  const MediaCellAnchor(
      {super.key, required this.messageId, required this.child});

  static final Map<int, List<_MediaCellAnchorState>> _registry = {};

  /// 该消息缩略图当前的全局屏幕 rect;不在渲染树上时返回 null
  static Rect? rectOf(int messageId) {
    final states = _registry[messageId];
    if (states == null) return null;
    for (final state in states.reversed.toList()) {
      final rect = state._globalRect();
      if (rect != null) return rect;
    }
    return null;
  }

  @override
  State<MediaCellAnchor> createState() => _MediaCellAnchorState();
}

class _MediaCellAnchorState extends State<MediaCellAnchor> {
  @override
  void initState() {
    super.initState();
    _register(widget.messageId);
  }

  @override
  void didUpdateWidget(MediaCellAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId) {
      _unregister(oldWidget.messageId);
      _register(widget.messageId);
    }
  }

  @override
  void dispose() {
    _unregister(widget.messageId);
    super.dispose();
  }

  void _register(int messageId) {
    MediaCellAnchor._registry.putIfAbsent(messageId, () => []).add(this);
  }

  void _unregister(int messageId) {
    final states = MediaCellAnchor._registry[messageId];
    states?.remove(this);
    if (states != null && states.isEmpty) {
      MediaCellAnchor._registry.remove(messageId);
    }
  }

  Rect? _globalRect() {
    if (!mounted) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
