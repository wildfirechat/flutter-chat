import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:chat/conversation/conversation_controller.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/widget/popup_menu_overlay.dart';

/// 消息正文的可选择包装(文本消息、流式消息共用):
/// - SelectionArea 提供选择能力,选区实时上报 controller;
/// - 焦点节点不参与焦点(canRequestFocus:false),这样弹菜单(showMenu 会抢焦点)时
///   SelectableRegion 不会因失焦清空选区,菜单显示期间保持选中高亮。
///   代价是气泡选区不响应 Cmd/Ctrl+C(复制走消息菜单),且跨消息的高亮清理
///   不再有失焦兜底,由 controller 通过 clearHighlight 回调协调;
/// - 内层手势比 SelectionArea 的识别器更深,在手势竞技场中优先胜出,
///   长按/右键仍弹消息菜单,而不是被 SelectionArea 拿去选词/弹系统菜单。
///
/// 两端的选区交互不同:
/// - 桌面端:鼠标拖选出选区,右键菜单里的"复制"只复制选中部分;
/// - 移动端:长按即全选正文并显示选择手柄,菜单跟着选区走(见 [_handleLongPressStart])。
///   菜单必须由 SelectionArea 的 contextMenuBuilder 出,不能再用整屏遮罩的
///   PopupMenuOverlay——遮罩会盖在手柄上层,选区就没法拖动调整了。
class SelectableMessageText extends StatefulWidget {
  const SelectableMessageText({
    super.key,
    required this.selectionKey,
    required this.controller,
    required this.onLongPressStart,
    required this.onSecondaryTapUp,
    required this.child,
    this.menuItemsBuilder,
    this.onMenuItemTap,
  });

  /// 选区归属标识,取 ConversationController.selectionKeyOf(message)
  final String selectionKey;
  final ConversationController? controller;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureTapUpCallback onSecondaryTapUp;
  final Widget child;

  /// 移动端长按后跟随选区弹出的菜单项;partialSelection 为 true(用户拖手柄
  /// 改过选择范围)时只给"复制"。为 null 时长按回退到整条消息的菜单。
  final List<Map<String, dynamic>> Function(bool partialSelection)? menuItemsBuilder;

  /// 菜单项点击;selectedText 非空表示用户调整过选区,操作只针对选中的部分
  final void Function(String value, String? selectedText)? onMenuItemTap;

  @override
  State<SelectableMessageText> createState() => _SelectableMessageTextState();
}

class _SelectableMessageTextState extends State<SelectableMessageText> {
  final GlobalKey<SelectionAreaState> _selectionAreaKey = GlobalKey<SelectionAreaState>();
  late final FocusNode _focusNode = FocusNode(canRequestFocus: false, skipTraversal: true);

  /// 当前选区文本
  String? _selectedText;

  /// 长按那一刻全选得到的文本。之后选区文本与它不一致,就说明用户拖手柄改过范围。
  String? _fullText;
  bool _selectingAll = false;

  /// 用户是否调整过选择范围。菜单在 overlay 里、不随本 State 重建,
  /// 用 notifier 让菜单项能在拖动手柄后立刻跟着变。
  final ValueNotifier<bool> _partialSelection = ValueNotifier<bool>(false);

  /// 长按全选 + 跟随选区弹菜单,只在移动端启用:桌面端没有手柄可拖,
  /// 右键菜单仍走 showMenu。
  bool get _inlineMenuEnabled => !isDesktopShell && widget.menuItemsBuilder != null && widget.onMenuItemTap != null;

  void _clearHighlight() {
    // 选区清空后 SelectableRegion 会连同手柄和菜单一起销毁
    _selectionAreaKey.currentState?.selectableRegion.clearSelection();
  }

  void _handleSelectionChanged(SelectedContent? content) {
    final String? text = content?.plainText;
    _selectedText = text;
    if (_selectingAll) {
      // selectAll 会先清一次选区,跳过那次空回调,取到全选文本才算数
      if (text != null && text.isNotEmpty) {
        _fullText = text;
      }
    } else if (text == null || text.isEmpty) {
      _fullText = null;
    }
    // 不是长按全选出来的选区就算"选了一部分":除了拖手柄改范围,
    // 移动端双击选词也走这里,菜单同样只给"复制"
    _partialSelection.value = text != null && text.isNotEmpty && text != _fullText;
    widget.controller?.setTextSelection(widget.selectionKey, text, clearHighlight: _clearHighlight);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    final SelectableRegionState? region = _selectionAreaKey.currentState?.selectableRegion;
    if (!_inlineMenuEnabled || region == null) {
      widget.onLongPressStart(details);
      return;
    }

    // 默认全选正文,并显示选择手柄和菜单(cause 为 toolbar 时 SelectableRegion 两者都出)
    _fullText = null;
    _selectingAll = true;
    HapticFeedback.selectionClick();
    region.selectAll(SelectionChangedCause.toolbar);
    _selectingAll = false;

    if (_fullText == null) {
      // 正文没有可选内容(比如整条消息只有一个动图表情),回退到整条消息的菜单
      widget.onLongPressStart(details);
    }
  }

  Widget _buildContextMenu(BuildContext context, SelectableRegionState state) {
    final itemsBuilder = widget.menuItemsBuilder;
    final onMenuItemTap = widget.onMenuItemTap;
    if (!_inlineMenuEnabled || itemsBuilder == null || onMenuItemTap == null) {
      return const SizedBox.shrink();
    }

    // primaryAnchor/secondaryAnchor 是选区顶边、底边的中点(全局坐标),
    // 拼成零宽矩形交给菜单面板,菜单就会贴着选区上方(放不下时转到下方)。
    // 底边多留出手柄的高度:菜单排到下方时不能盖住手柄,否则选区没法再拖动调整。
    const double handleAllowance = 28;
    final anchors = state.contextMenuAnchors;
    final Offset above = anchors.primaryAnchor;
    final Offset below = anchors.secondaryAnchor ?? anchors.primaryAnchor;
    final Rect targetRect = Rect.fromLTRB(above.dx, above.dy, above.dx, below.dy + handleAllowance);

    return ValueListenableBuilder<bool>(
      valueListenable: _partialSelection,
      builder: (context, partialSelection, _) {
        final items = itemsBuilder(partialSelection);
        return PopupMenuPanel(
          targetRect: targetRect,
          menuItems: items,
          popupWidth: PopupMenuPanel.widthForItems(items.length),
          crossAxisCount: items.length < 4 ? items.length : 4,
          onItemTap: (value) {
            final String? selectedText = partialSelection ? _selectedText : null;
            _clearHighlight();
            onMenuItemTap(value, selectedText);
          },
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant SelectableMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 流式消息生成结束落库后标识会从 stream-* 变成 msg-*,此时正文也从 Text 换成 Linkify、
    // 选区随之失效,把旧标识的登记解除,避免 controller 里残留一条选不中的选区
    if (oldWidget.selectionKey != widget.selectionKey) {
      (oldWidget.controller ?? widget.controller)?.detachTextSelection(oldWidget.selectionKey);
      _fullText = null;
      _selectedText = null;
      _partialSelection.value = false;
    }
  }

  @override
  void dispose() {
    // cell 滚出列表被回收时选区随 State 一起消失,同步解除 controller 的登记,
    // 避免 clearHighlight 回调指向已销毁的 State
    widget.controller?.detachTextSelection(widget.selectionKey);
    _partialSelection.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      key: _selectionAreaKey,
      focusNode: _focusNode,
      contextMenuBuilder: _buildContextMenu,
      onSelectionChanged: _handleSelectionChanged,
      child: RawGestureDetector(
        gestures: {
          // 桌面端不挂长按:鼠标按下后停顿超过 500ms 再拖,长按会抢赢手势竞技场,
          // SelectableRegion 的鼠标识别器被判负后触发 onCancel → clearSelection,
          // 拖选就选不出东西/选区被清掉。PC 端的消息菜单本来就走右键。
          if (!isDesktopShell)
            LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(debugOwner: this),
              (instance) => instance.onLongPressStart = _handleLongPressStart,
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
