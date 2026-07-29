import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:chat/conversation/conversation_controller.dart';

/// 消息正文的可选择包装(文本消息、流式消息共用):
/// - SelectionArea 提供选择能力,选区实时上报 controller;
/// - 焦点节点不参与焦点(canRequestFocus:false),这样弹菜单(showMenu 会抢焦点)时
///   SelectableRegion 不会因失焦清空选区,菜单显示期间保持选中高亮。
///   代价是气泡选区不响应 Cmd/Ctrl+C(复制走消息菜单),且跨消息的高亮清理
///   不再有失焦兜底,由 controller 通过 clearHighlight 回调协调;
/// - 内层手势比 SelectionArea 的识别器更深,在手势竞技场中优先胜出,
///   长按/右键仍弹消息菜单,而不是被 SelectionArea 拿去选词/弹系统菜单。
class SelectableMessageText extends StatefulWidget {
  const SelectableMessageText({
    super.key,
    required this.selectionKey,
    required this.controller,
    required this.onLongPressStart,
    required this.onSecondaryTapUp,
    required this.child,
  });

  /// 选区归属标识,取 ConversationController.selectionKeyOf(message)
  final String selectionKey;
  final ConversationController? controller;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureTapUpCallback onSecondaryTapUp;
  final Widget child;

  @override
  State<SelectableMessageText> createState() => _SelectableMessageTextState();
}

class _SelectableMessageTextState extends State<SelectableMessageText> {
  final GlobalKey<SelectionAreaState> _selectionAreaKey = GlobalKey<SelectionAreaState>();
  late final FocusNode _focusNode = FocusNode(canRequestFocus: false, skipTraversal: true);

  void _clearHighlight() {
    _selectionAreaKey.currentState?.selectableRegion.clearSelection();
  }

  @override
  void didUpdateWidget(covariant SelectableMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 流式消息生成结束落库后标识会从 stream-* 变成 msg-*,此时正文也从 Text 换成 Linkify、
    // 选区随之失效,把旧标识的登记解除,避免 controller 里残留一条选不中的选区
    if (oldWidget.selectionKey != widget.selectionKey) {
      (oldWidget.controller ?? widget.controller)?.detachTextSelection(oldWidget.selectionKey);
    }
  }

  @override
  void dispose() {
    // cell 滚出列表被回收时选区随 State 一起消失,同步解除 controller 的登记,
    // 避免 clearHighlight 回调指向已销毁的 State
    widget.controller?.detachTextSelection(widget.selectionKey);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      key: _selectionAreaKey,
      focusNode: _focusNode,
      onSelectionChanged: (content) =>
          widget.controller?.setTextSelection(widget.selectionKey, content?.plainText, clearHighlight: _clearHighlight),
      child: RawGestureDetector(
        gestures: {
          LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(debugOwner: this),
            (instance) => instance.onLongPressStart = widget.onLongPressStart,
          ),
          _EagerSecondaryTapRecognizer: GestureRecognizerFactoryWithHandlers<_EagerSecondaryTapRecognizer>(
            () => _EagerSecondaryTapRecognizer(debugOwner: this),
            (instance) => instance.onSecondaryTapUp = widget.onSecondaryTapUp,
          ),
        },
        child: widget.child,
      ),
    );
  }
}

/// 右键按下即宣告胜出的识别器。
/// SelectableRegion 的右键识别器(TapGestureRecognizer.onSecondaryTapDown)会在
/// 100ms deadline 时提前回调——即使它最终输掉竞技场,"选中点击处单词"的副作用
/// 也已经发生。在 pointer down 时立即 resolve,让它在 deadline 前出局,
/// 右键就不会再改动选区。
class _EagerSecondaryTapRecognizer extends OneSequenceGestureRecognizer {
  _EagerSecondaryTapRecognizer({super.debugOwner});

  GestureTapUpCallback? onSecondaryTapUp;

  @override
  bool isPointerAllowed(PointerDownEvent event) => event.buttons == kSecondaryButton && onSecondaryTapUp != null;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent) {
      onSecondaryTapUp?.call(TapUpDetails(
        kind: event.kind,
        globalPosition: event.position,
        localPosition: event.localPosition,
      ));
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'eager secondary tap';
}
