import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chat/sticker/sticker_source.dart';
import 'package:chat/sticker/sticker_view.dart';
import 'package:chat/theme/app_colors.dart';
import 'message_input_bar_controller.dart';

/// 输入联想贴纸条(微信"表情联想"):输入框里的文字命中贴纸关键词时浮在 [child] 上方,
/// 点一下发送贴纸并清掉输入;桌面端还能用方向键选、回车发(见 [handleKeyEvent])。
/// 显示哪些、选中哪个都由 [MessageInputBarController] 决定,移动端与桌面端输入栏共用。
///
/// 浮层在 [child] 的范围之外,放进 Stack 溢出部分点不到,所以借 [OverlayPortal] 画进 Overlay,
/// 再用 [CompositedTransformFollower] 跟住 [child]:键盘弹收、输入栏变高时逐帧贴住。
class StickerSuggestionOverlay extends StatefulWidget {
  const StickerSuggestionOverlay({
    super.key,
    required this.alignment,
    this.offset = Offset.zero,
    required this.child,
  });

  /// 联想条底边与 [child] 的对齐点:[Alignment.topLeft] 左对齐、[Alignment.topRight] 右对齐。
  final Alignment alignment;

  /// 在对齐点基础上的偏移,负的 dy 往上留出空隙。
  final Offset offset;

  final Widget child;

  /// 桌面端输入框的按键处理,联想条可见时调用方应先交给它:
  /// ↑ 进入联想条并选中第一个,←/→ 切换,Enter 发送选中的贴纸,↓ 回到文字,Esc 收起联想条。
  /// 没选中时 ←/→/Enter 不拦截,照常移动光标、发送文字 —— 打完"好的"直接回车发的还是文字。
  static KeyEventResult handleKeyEvent(
      MessageInputBarController controller, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    // 输入法组合中联想条本来就不显示,按键全归输入法
    final List<String> stickers = controller.stickerSuggestions;
    if (stickers.isEmpty) {
      return KeyEventResult.ignored;
    }
    final int highlight = controller.stickerSuggestionHighlight;
    final LogicalKeyboardKey key = event.logicalKey;
    final bool isRepeat = event is KeyRepeatEvent;

    if (key == LogicalKeyboardKey.escape) {
      if (!isRepeat) {
        controller.dismissStickerSuggestions();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (highlight < 0) {
        controller.highlightStickerSuggestion(0);
      }
      // 已经在联想条里:吃掉,不让光标在文字里跑
      return KeyEventResult.handled;
    }
    if (highlight < 0) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      controller.highlightStickerSuggestion(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      controller.highlightStickerSuggestion(math.max(0, highlight - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      controller.highlightStickerSuggestion(highlight + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (!isRepeat) {
        controller.sendSuggestedSticker(stickers[highlight]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  State<StickerSuggestionOverlay> createState() =>
      _StickerSuggestionOverlayState();
}

class _StickerSuggestionOverlayState extends State<StickerSuggestionOverlay> {
  static const double _stickerSize = 64;
  static const double _cellPadding = 6;
  static const double _cellExtent = _stickerSize + 2 * _cellPadding;
  static const double _panelPadding = 6;

  /// 一排最多露出的个数,再多横向滑动
  static const int _maxVisibleCells = 6;

  /// 与屏幕左右边缘至少留的空隙
  static const double _screenMargin = 8;

  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();
  final ScrollController _scrollController = ScrollController();

  /// 上一次显示的联想结果,换了一批就滚回开头
  List<String>? _shownStickers;

  @override
  void initState() {
    super.initState();
    // 浮层常驻,有没有内容交给里面的 Selector:显隐直接跟着控制器通知走,
    // 不用在监听回调里命令式 show/hide,也就不用处理控制器实例被替换
    _portal.show();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: CompositedTransformTarget(link: _link, child: widget.child),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: widget.alignment,
        followerAnchor: Alignment(widget.alignment.x, 1),
        offset: widget.offset,
        // 先取结果再取选中:结果变了会复位选中
        child: Selector<MessageInputBarController, (List<String>, int)>(
          selector: (_, controller) => (
            controller.stickerSuggestions,
            controller.stickerSuggestionHighlight,
          ),
          builder: (context, selection, _) {
            final (stickers, highlight) = selection;
            if (stickers.isEmpty) {
              _shownStickers = null;
              return const SizedBox.shrink();
            }
            _scrollAfterLayout(highlight, !identical(stickers, _shownStickers));
            _shownStickers = stickers;
            return _buildPanel(context, stickers, highlight);
          },
        ),
      ),
    );
  }

  /// 换了一批结果滚回开头;键盘选中的贴纸滚进可见范围。要等这一帧排版完才知道滚动范围。
  void _scrollAfterLayout(int highlight, bool resetToStart) {
    if (highlight < 0 && !resetToStart) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final ScrollPosition position = _scrollController.position;
      double target = resetToStart ? 0 : position.pixels;
      if (highlight >= 0) {
        // 格子在内容里的范围,两侧带上面板内边距,滚到边上时不贴边
        final double start = highlight * _cellExtent;
        final double end = start + _cellExtent + 2 * _panelPadding;
        if (start < target) {
          target = start;
        } else if (end > target + position.viewportDimension) {
          target = end - position.viewportDimension;
        }
      }
      target = target
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (target != position.pixels) {
        position.jumpTo(target);
      }
    });
  }

  Widget _buildPanel(
      BuildContext context, List<String> stickers, int highlight) {
    final colors = context.colors;
    final controller =
        Provider.of<MessageInputBarController>(context, listen: false);
    // 不超出屏幕,也不超出被跟随的输入栏/输入框(桌面端会话区可能很窄)。
    // leaderSize 是上一次排版的结果,联想条出现时输入栏早已排好,够用
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double anchorWidth =
        (_link.leaderSize?.width ?? screenWidth) - widget.offset.dx.abs();
    final double maxWidth = math.min(
      math.min(screenWidth - 2 * _screenMargin, anchorWidth),
      _maxVisibleCells * _cellExtent + 2 * _panelPadding,
    );

    // 桌面端点输入框以外的地方会让输入框失焦,联想条随之收起,点击落空;
    // 算作输入框的一部分,点贴纸时输入框保留焦点,发完可以接着打字
    return TextFieldTapRegion(
      child: Material(
        color: colors.popupBg,
        elevation: 6,
        shadowColor: colors.shadow,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(_panelPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < stickers.length; i++)
                  _buildCell(controller, stickers[i], i == highlight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(
      MessageInputBarController controller, String path, bool highlighted) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(8);
    return Ink(
      // 联想结果变化时同一个贴纸保持原组件,动画不从头播
      key: ValueKey(path),
      decoration: BoxDecoration(
        color: highlighted ? colors.accentSoft : null,
        borderRadius: borderRadius,
      ),
      child: InkWell(
        onTap: () => controller.sendSuggestedSticker(path),
        borderRadius: borderRadius,
        hoverColor: colors.cellHoverDesktop,
        child: Padding(
          padding: const EdgeInsets.all(_cellPadding),
          child: StickerView(
            StickerSource.asset(path),
            width: _stickerSize,
            height: _stickerSize,
          ),
        ),
      ),
    );
  }
}
