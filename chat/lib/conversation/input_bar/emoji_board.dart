import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/viewmodel/font_size_view_model.dart';
import 'package:chat/widgets/animated_emoji.dart';
import 'package:chat/sticker/sticker_pack.dart';
import 'package:chat/sticker/sticker_source.dart';
import 'package:chat/sticker/sticker_view.dart';
import 'input_bar_icon.dart';
import 'package:chat/app_shell.dart';

typedef OnPickerEmojiCallback = void Function(String emoji);
typedef OnDelEmojiCallback = void Function();
typedef OnPickerStickerCallback = void Function(String stickerPath);

/// 内置 emoji 列表,移动端输入栏与桌面端表情弹层共用。
const List<String> kChatEmojis = [
  '😊',
  '😨',
  '😍',
  '😳',
  '😎',
  '😭',
  '😌',
  '😵',
  '😴',
  '😢',
  '😅',
  '😡',
  '😜',
  '😀',
  '😲',
  '😟',
  '😤',
  '😞',
  '😫',
  '😣',
  '😈',
  '😉',
  '😯',
  '😕',
  '😰',
  '😋',
  '😝',
  '😓',
  '😃',
  '😂',
  '😘',
  '😒',
  '😏',
  '😶',
  '😱',
  '😖',
  '😩',
  '😔',
  '😑',
  '😚',
  '😪',
  '😇',
  '🙊',
  '👊',
  '👎',
  '☝',
  '✌',
  '😬',
  '😷',
  '🙈',
  '👌',
  '👏',
  '✊',
  '💪',
  '😆',
  '☺',
  '🙉',
  '👍',
  '🙏',
  '✋',
  '☀',
  '☕',
  '⛄',
  '📚',
  '🎁',
  '🎉',
  '🍦',
  '☁',
  '❄',
  '⚡',
  '💰',
  '🎂',
  '🎓',
  '🍖',
  '☔',
  '⛅',
  '✏',
  '💩',
  '🎄',
  '🍷',
  '🎤',
  '🏀',
  '🀄',
  '💣',
  '📢',
  '🌏',
  '🍫',
  '🎲',
  '🏂',
  '💡',
  '💤',
  '🚫',
  '🌻',
  '🍻',
  '🎵',
  '🏡',
  '💢',
  '📞',
  '🚿',
  '🍚',
  '👪',
  '👼',
  '💊',
  '🔫',
  '🌹',
  '🐶',
  '💄',
  '👫',
  '👽',
  '💋',
  '🌙',
  '🍉',
  '🐷',
  '💔',
  '👻',
  '👿',
  '💍',
  '🌲',
  '🐴',
  '👑',
  '🔥',
  '⭐',
  '⚽',
  '🕖',
  '⏰',
  '😁',
  '🚀',
  '⏳',
  '🏡'
];

/// 面板底色。桌面端弹层要把卡片(含指向表情按钮的小尾巴)刷成同一个颜色,
/// 尾巴才不会和面板脱色,所以对外暴露。
Color emojiBoardBackgroundColor(BuildContext context) => AppShell.isDesktopStyle
    ? context.colors.chatBgDesktop
    : context.colors.chatBg;

class EmojiBoard extends StatefulWidget {
  final List<String> emojis;
  final OnPickerEmojiCallback pickerEmojiCallback;
  final OnDelEmojiCallback delEmojiCallback;
  final OnPickerStickerCallback? pickerStickerCallback;
  final double? height;

  const EmojiBoard(
    this.emojis, {
    Key? key,
    required this.pickerEmojiCallback,
    required this.delEmojiCallback,
    this.pickerStickerCallback,
    this.height,
  }) : super(key: key);

  @override
  State<EmojiBoard> createState() => _EmojiBoardState();
}

/// 滑动流畅度相关的几处约定:
/// - 各页 widget 实例缓存在这里。父级重建(键盘收起时逐帧)、翻页切换选中 tab 时,
///   同一个实例原样回到树上,Flutter 直接跳过,格子不会跟着重建;
/// - 翻页只通过 [_selectedPage]/[_settledPage] 通知 tab 栏和贴纸页,不 setState 整个面板;
/// - 格子自己的预建和动画暂停见 [_EmojiGridPage]、[StickerGridPage]。
class _EmojiBoardState extends State<EmojiBoard> {
  final PageController _pageController = PageController();

  /// tab 高亮,翻过一半就切换(即 PageView.onPageChanged 的时机)。0 为 emoji,1+ 为贴纸包
  final ValueNotifier<int> _selectedPage = ValueNotifier(0);

  /// 停稳的页,翻页进行中为 null。贴纸页据此决定是否播放动画
  final ValueNotifier<int?> _settledPage = ValueNotifier(0);

  List<StickerPack> _packs = StickerPacks.loaded;

  Widget? _emojiPage;

  /// 贴纸包 id → 页面
  final Map<String, Widget> _stickerPages = {};

  OverlayEntry? _overlayEntry;

  // Unified preview state
  final ValueNotifier<_PreviewData?> _previewNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    StickerPacks.load().then((packs) {
      // 已经加载过时拿到的是同一个列表,不用再重建一遍
      if (mounted && !identical(packs, _packs)) {
        setState(() {
          _packs = packs;
          _stickerPages.clear();
        });
      }
    });
  }

  @override
  void didUpdateWidget(EmojiBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emojis != widget.emojis) {
      _emojiPage = null;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hidePreview();
    _previewNotifier.dispose();
    _selectedPage.dispose();
    _settledPage.dispose();
    super.dispose();
  }

  // 缓存的页面拿的是这几个方法,调用时再读最新的 widget 回调,父级换了回调也不用重建页面
  void _onEmojiPicked(String emoji) => widget.pickerEmojiCallback(emoji);

  void _onEmojiDeleted() => widget.delEmojiCallback();

  void _onStickerPicked(String stickerPath) =>
      widget.pickerStickerCallback?.call(stickerPath);

  void _showEmojiPreview(Offset cellCenterGlobal, String emoji) {
    _previewNotifier.value =
        _PreviewData(emoji: emoji, position: cellCenterGlobal);
    _ensureOverlayVisible();
  }

  void _showStickerPreview(String stickerPath) {
    _previewNotifier.value = _PreviewData(stickerPath: stickerPath);
    _ensureOverlayVisible();
  }

  void _ensureOverlayVisible() {
    if (_overlayEntry != null) return;

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(builder: (context) {
      return ValueListenableBuilder<_PreviewData?>(
        valueListenable: _previewNotifier,
        builder: (context, data, child) {
          if (data == null) return const SizedBox.shrink();

          if (data.emoji != null && data.position != null) {
            final fontSizeViewModel = Provider.of<FontSizeViewModel>(context);
            final fontScale = fontSizeViewModel.textScaleFactor;
            final double previewWidth = 60 * fontScale;
            final double previewHeight = 60 * fontScale;
            final double arrowWidth = 12 * fontScale;
            final double arrowHeight = 8 * fontScale;

            // Emoji Preview
            return Positioned(
              left: data.position!.dx - previewWidth / 2,
              top: data.position!.dy -
                  (previewHeight + arrowHeight + 32 * fontScale),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.noScaling,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      Container(
                        width: previewWidth,
                        height: previewHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.colors.popupBg,
                          borderRadius: BorderRadius.circular(8 * fontScale),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4 * fontScale,
                              offset: Offset(0, 2 * fontScale),
                            )
                          ],
                        ),
                        child: AnimatedEmojiWidget(
                          emoji: data.emoji!,
                          size: 36 * fontScale,
                        ),
                      ),
                      CustomPaint(
                        size: Size(arrowWidth, arrowHeight),
                        painter: _TrianglePainter(context.colors.popupBg),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else if (data.stickerPath != null) {
            // Sticker Preview
            return Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 160,
                  height: 160,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.colors.popupBg,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: StickerView(
                    StickerSource.asset(data.stickerPath!),
                    width: 140,
                    height: 140,
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      );
    });
    overlay.insert(_overlayEntry!);
  }

  void _hidePreview() {
    _previewNotifier.value = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// 只看 PageView 自己的翻页(depth 0);页内格子的上下滚动 depth 更深,由各页自己处理
  bool _handlePageScroll(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      _settledPage.value = null;
    } else if (notification is ScrollEndNotification) {
      // PageView 内部的 onPageChanged 先于这里收到通知,停稳时 _selectedPage 就是当前页
      _settledPage.value = _selectedPage.value;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height ?? 280,
      color: emojiBoardBackgroundColor(context),
      child: Column(
        children: [
          // Tab Bar (Top Row as requested)
          _buildTabBar(),
          // Content Area
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handlePageScroll,
              child: PageView.builder(
                controller: _pageController,
                itemCount: 1 + _packs.length,
                onPageChanged: (index) {
                  _hidePreview();
                  _selectedPage.value = index;
                },
                itemBuilder: (context, index) =>
                    index == 0 ? _emojiPageWidget() : _stickerPageWidget(index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emojiPageWidget() {
    return _emojiPage ??= _EmojiGridPage(
      emojis: widget.emojis,
      onPicked: _onEmojiPicked,
      onDelete: _onEmojiDeleted,
      onPreviewShow: _showEmojiPreview,
      onPreviewHide: _hidePreview,
    );
  }

  Widget _stickerPageWidget(int index) {
    final pack = _packs[index - 1];
    return _stickerPages[pack.id] ??= StickerGridPage(
      key: ValueKey(pack.id),
      stickerPaths: pack.stickerPaths,
      pageIndex: index,
      settledPage: _settledPage,
      onStickerSelected: _onStickerPicked,
      onPreviewShow: _showStickerPreview,
      onPreviewHide: _hidePreview,
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
            bottom: BorderSide(color: context.colors.hairlineSoft, width: 0.5)),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: _selectedPage,
        builder: (context, selectedPage, _) => ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 1 + _packs.length,
          itemBuilder: (context, index) {
            bool isSelected = selectedPage == index;
            return Material(
              color: isSelected
                  ? emojiBoardBackgroundColor(context)
                  : context.colors.surface,
              child: InkWell(
                onTap: () {
                  _pageController.jumpToPage(index);
                },
                child: Container(
                  width: 50,
                  padding: const EdgeInsets.all(8),
                  child: index == 0
                      ? InputBarIcon(InputBarGlyph.emoji,
                          size: 24, color: context.colors.iconSecondary)
                      : _buildPackCover(_packs[index - 1]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPackCover(StickerPack pack) {
    final cover = StickerView(
      StickerSource.asset(pack.coverPath),
      width: 34,
      height: 34,
      animate: false,
    );
    // 桌面端悬停显示包名;移动端长按会和翻页手势冲突,不加
    return AppShell.isPointerInput
        ? Tooltip(
            message: pack.titleFor(Localizations.localeOf(context)),
            child: cover,
          )
        : cover;
  }
}

/// emoji 页。
///
/// 表情数量固定且不多,整页格子一次建好(cacheExtent 覆盖全部内容),上下滑动时只移动图层,
/// 不再每滑过一行就新建一行格子 —— 逐行创建是滑动一顿一顿的主要来源。
/// 页面 keep-alive,翻到贴纸页再翻回来不用重建这一百多个格子。
/// 格子共用页面上一块透明 [Material] 画水波纹,不再每格一个 Material。
class _EmojiGridPage extends StatefulWidget {
  const _EmojiGridPage({
    required this.emojis,
    required this.onPicked,
    required this.onDelete,
    required this.onPreviewShow,
    required this.onPreviewHide,
  });

  final List<String> emojis;
  final OnPickerEmojiCallback onPicked;
  final OnDelEmojiCallback onDelete;
  final void Function(Offset cellCenterGlobal, String emoji) onPreviewShow;
  final VoidCallback onPreviewHide;

  @override
  State<_EmojiGridPage> createState() => _EmojiGridPageState();
}

class _EmojiGridPageState extends State<_EmojiGridPage>
    with AutomaticKeepAliveClientMixin {
  static const double _paddingTop = 10;
  static const double _paddingBottom = 50;
  static const double _textSize = 28;
  static const double _delSizeX = 48;
  static const double _delSizeY = 38;
  static const double _delPadding = 5;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _gridKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  /// 每行表情数,字号调大后减少。移动端默认一行 7 个,8 个太挤;桌面弹层窄,保持 8 个
  static int _columnCount(int fontIndex) {
    if (fontIndex >= 4) {
      return 6;
    }
    if (fontIndex == 3 || !AppShell.isDesktopStyle) {
      return 7;
    }
    return 8;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updatePreview(Offset globalPosition) {
    RenderBox? renderBox =
        _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    Offset localPosition = renderBox.globalToLocal(globalPosition);
    final int lineCount = _columnCount(
        Provider.of<FontSizeViewModel>(context, listen: false).index);
    double cellWidth = renderBox.size.width / lineCount;
    double cellHeight = cellWidth; // Aspect ratio 1.0

    double effectiveY =
        localPosition.dy - _paddingTop + _scrollController.offset;

    int col = (localPosition.dx / cellWidth).floor();
    int row = (effectiveY / cellHeight).floor();

    int index = row * lineCount + col;

    if (index >= 0 && index < widget.emojis.length) {
      // Calculate cell center
      double cellCenterX = (col + 0.5) * cellWidth;
      double cellCenterY =
          (row + 0.5) * cellHeight - _scrollController.offset + _paddingTop;
      Offset cellCenterGlobal =
          renderBox.localToGlobal(Offset(cellCenterX, cellCenterY));

      widget.onPreviewShow(cellCenterGlobal, widget.emojis[index]);
    } else {
      widget.onPreviewHide();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final fontSizeViewModel = Provider.of<FontSizeViewModel>(context);
    final fontScale = fontSizeViewModel.textScaleFactor;
    final int lineCount = _columnCount(fontSizeViewModel.index);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 删除按钮贴在右下角,内缩量与表情格子的留白对齐。
        // 取面板自身宽度而非屏幕宽度:桌面端面板是窄弹层,用屏幕宽会把按钮推到面板中间。
        final double scaledTextSize = _textSize * fontScale;
        double paddingSize =
            ((constraints.maxWidth - scaledTextSize * lineCount) /
                    lineCount /
                    2)
                .clamp(0.0, double.infinity);

        // 正方形格子,内容总高 = 行数 × 格宽 + 上下留白
        final double contentExtent = (widget.emojis.length / lineCount).ceil() *
                (constraints.maxWidth / lineCount) +
            _paddingTop +
            _paddingBottom;

        return Stack(
          children: [
            GestureDetector(
              onLongPressStart: (details) =>
                  _updatePreview(details.globalPosition),
              onLongPressMoveUpdate: (details) =>
                  _updatePreview(details.globalPosition),
              onLongPressEnd: (_) => widget.onPreviewHide(),
              child: Material(
                type: MaterialType.transparency,
                child: GridView.builder(
                  key: _gridKey,
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                      top: _paddingTop, bottom: _paddingBottom),
                  cacheExtent: contentExtent,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: lineCount),
                  itemCount: widget.emojis.length,
                  itemBuilder: (context, index) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => widget.onPicked(widget.emojis[index]),
                      child: Center(
                        child: Text(
                          widget.emojis[index],
                          style: const TextStyle(fontSize: _textSize),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: paddingSize,
              bottom: paddingSize,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  padding: const EdgeInsets.all(_delPadding),
                  decoration: BoxDecoration(
                    color: context.colors.inputBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SizedBox(
                    width: _delSizeX - 2 * _delPadding,
                    height: _delSizeY - 2 * _delPadding,
                    child: Image.asset(
                      'assets/images/input/del_emoji.png',
                    ),
                  ),
                ),
              ),
            )
          ],
        );
      },
    );
  }
}

/// 贴纸格子的排布。GridView 的参数、长按命中、可见区间都从这里算,改一处即可。
class _StickerGridLayout {
  const _StickerGridLayout(this.width);

  static const int columns = 4;
  static const double spacing = 10;
  static const double padding = 10;

  static const SliverGridDelegate gridDelegate =
      SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: spacing,
    crossAxisSpacing: spacing,
  );

  /// 整个网格(含左右留白)的宽度
  final double width;

  /// 正方形格子的边长
  double get cellExtent =>
      (width - 2 * padding - (columns - 1) * spacing) / columns;

  double get stride => cellExtent + spacing;

  /// 前 [itemCount] 个格子连同上下留白占的高度
  double contentExtent(int itemCount) {
    final int rows = (itemCount / columns).ceil();
    return 2 * padding + rows * cellExtent + math.max(rows - 1, 0) * spacing;
  }

  /// 滚动到 [scrollOffset] 时视口里露出来的格子,下标区间 [start, end)
  (int, int) visibleRange(
      double scrollOffset, double viewportExtent, int itemCount) {
    final int firstRow =
        math.max(((scrollOffset - padding) / stride).floor(), 0);
    final int endRow =
        ((scrollOffset + viewportExtent - padding) / stride).ceil();
    return (
      math.min(firstRow * columns, itemCount),
      math.min(math.max(endRow, firstRow) * columns, itemCount),
    );
  }
}

/// 一个贴纸包的页面。
///
/// 每格一个 Lottie,逐帧解析图层、绘制都很吃主线程,滑动时的开销控制:
/// - 只有停稳的当前页、视口里露出来的格子才播放;翻页、上下滚动过程中全部暂停,停下后再按
///   新位置恢复;
/// - 首次成为当前页后把整包格子建好(缓存区覆盖全部内容,上限见 `_maxPrebuiltItems`),之后
///   上下滑动不再逐行新建、销毁 Lottie,已录好的绘制指令缓存也不会随格子销毁而丢掉。
///   放在翻页停稳之后而不是页面一出现就建,避免翻页途中一次建几十个格子。
class StickerGridPage extends StatefulWidget {
  final List<String> stickerPaths;

  /// 本页在面板 PageView 里的下标,[settledPage] 等于它时本页才播放动画
  final int pageIndex;

  /// 面板停稳的页,翻页过程中为 null
  final ValueListenable<int?> settledPage;
  final Function(String) onStickerSelected;
  final Function(String) onPreviewShow;
  final Function() onPreviewHide;

  const StickerGridPage({
    Key? key,
    required this.stickerPaths,
    required this.pageIndex,
    required this.settledPage,
    required this.onStickerSelected,
    required this.onPreviewShow,
    required this.onPreviewHide,
  }) : super(key: key);

  @override
  State<StickerGridPage> createState() => _StickerGridPageState();
}

class _StickerGridPageState extends State<StickerGridPage>
    with AutomaticKeepAliveClientMixin {
  /// 预建格子数上限。内置贴纸包都是几十个,整包预建;
  /// 以后真有超大的包,超出部分照旧滚到附近才建,不会一次建几百个
  static const int _maxPrebuiltItems = 120;

  static const BorderRadius _cellRadius = BorderRadius.all(Radius.circular(8));

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _gridKey = GlobalKey();
  final ValueNotifier<int?> _previewingIndexNotifier = ValueNotifier(null);

  /// 允许播放动画的格子,下标区间 [start, end);不该播放时为 null
  final ValueNotifier<(int, int)?> _animatingRange = ValueNotifier(null);

  /// 最近一次布局的网格宽度,首次布局前为 null
  _StickerGridLayout? _layout;

  /// 本页网格正在滚动(拖动或惯性)
  bool _scrolling = false;

  bool _prebuildAll = false;

  @override
  bool get wantKeepAlive => true;

  bool get _isSettledPage => widget.settledPage.value == widget.pageIndex;

  @override
  void initState() {
    super.initState();
    // 点 tab 直接跳过来时,页面建出来之前就已经停稳了
    _prebuildAll = _isSettledPage;
    widget.settledPage.addListener(_onSettledPageChanged);
  }

  @override
  void didUpdateWidget(StickerGridPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settledPage != widget.settledPage) {
      oldWidget.settledPage.removeListener(_onSettledPageChanged);
      widget.settledPage.addListener(_onSettledPageChanged);
    }
    if (_isSettledPage) {
      _prebuildAll = true;
    }
    _refreshAnimatingRange();
  }

  @override
  void dispose() {
    widget.settledPage.removeListener(_onSettledPageChanged);
    _scrollController.dispose();
    _previewingIndexNotifier.dispose();
    _animatingRange.dispose();
    super.dispose();
  }

  void _onSettledPageChanged() {
    if (_isSettledPage && !_prebuildAll) {
      setState(() => _prebuildAll = true);
    }
    _refreshAnimatingRange();
  }

  void _refreshAnimatingRange() {
    final layout = _layout;
    if (_scrolling ||
        !_isSettledPage ||
        layout == null ||
        !_scrollController.hasClients) {
      _animatingRange.value = null;
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      _animatingRange.value = null;
      return;
    }
    _animatingRange.value = layout.visibleRange(position.pixels,
        position.viewportDimension, widget.stickerPaths.length);
  }

  /// 只看本页网格自己的滚动
  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      _scrolling = true;
      _refreshAnimatingRange();
    } else if (notification is ScrollEndNotification) {
      _scrolling = false;
      _refreshAnimatingRange();
    }
    return false;
  }

  /// 首次布局、尺寸变化(旋转、面板高度变化)后可见区间要重算
  bool _handleMetricsChanged(ScrollMetricsNotification notification) {
    if (notification.depth == 0) {
      _refreshAnimatingRange();
    }
    return false;
  }

  void _handleLongPressUpdate(Offset globalPosition) {
    RenderBox? renderBox =
        _gridKey.currentContext?.findRenderObject() as RenderBox?;
    final layout = _layout;
    if (renderBox == null || layout == null) return;

    Offset localPosition = renderBox.globalToLocal(globalPosition);
    const double padding = _StickerGridLayout.padding;

    double effectiveX = localPosition.dx - padding;
    double effectiveY = localPosition.dy - padding + _scrollController.offset;

    if (effectiveX < 0 || effectiveX > layout.width - 2 * padding) {
      _clearPreview();
      return;
    }

    double itemExtent = layout.cellExtent;
    double stride = layout.stride;

    int col = (effectiveX / stride).floor();
    int row = (effectiveY / stride).floor();

    // Check if within item bounds (ignoring spacing gaps)
    double relativeX = effectiveX - col * stride;
    double relativeY = effectiveY - row * stride;

    if (col >= 0 &&
        col < _StickerGridLayout.columns &&
        relativeX <= itemExtent &&
        relativeY <= itemExtent) {
      int index = row * _StickerGridLayout.columns + col;
      if (index >= 0 && index < widget.stickerPaths.length) {
        if (_previewingIndexNotifier.value != index) {
          _previewingIndexNotifier.value = index;
          widget.onPreviewShow(widget.stickerPaths[index]);
        }
        return;
      }
    }
    // 滑动到间隙时不清除预览，保持上一个预览，防止闪烁
    // 只有当手指完全离开 Grid 区域或长按结束时才清除
  }

  void _clearPreview() {
    if (_previewingIndexNotifier.value != null) {
      _previewingIndexNotifier.value = null;
      widget.onPreviewHide();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _StickerGridLayout(constraints.maxWidth);
        _layout = layout;
        final int itemCount = widget.stickerPaths.length;

        return NotificationListener<ScrollMetricsNotification>(
          onNotification: _handleMetricsChanged,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScroll,
            child: GestureDetector(
              onLongPressStart: (details) =>
                  _handleLongPressUpdate(details.globalPosition),
              onLongPressMoveUpdate: (details) =>
                  _handleLongPressUpdate(details.globalPosition),
              onLongPressEnd: (_) => _clearPreview(),
              child: Material(
                type: MaterialType.transparency,
                child: GridView.builder(
                  key: _gridKey,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(_StickerGridLayout.padding),
                  cacheExtent: _prebuildAll
                      ? layout
                          .contentExtent(math.min(itemCount, _maxPrebuiltItems))
                      : null,
                  gridDelegate: _StickerGridLayout.gridDelegate,
                  itemCount: itemCount,
                  itemBuilder: _buildCell,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(BuildContext context, int index) {
    final String path = widget.stickerPaths[index];
    return InkWell(
      borderRadius: _cellRadius,
      onTap: () => widget.onStickerSelected(path),
      child: ValueListenableBuilder<int?>(
        valueListenable: _previewingIndexNotifier,
        builder: (context, previewingIndex, child) => DecoratedBox(
          decoration: BoxDecoration(
            color: previewingIndex == index ? Colors.black12 : null,
            borderRadius: _cellRadius,
          ),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          // 暂停只包住贴纸本身:包在 InkWell 外面会连水波纹动画一起冻住
          child: ValueListenableBuilder<(int, int)?>(
            valueListenable: _animatingRange,
            builder: (context, range, sticker) => TickerMode(
              enabled: range != null && index >= range.$1 && index < range.$2,
              child: sticker!,
            ),
            child: StickerView(
              StickerSource.asset(path),
              decodeSize: 240,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

class _PreviewData {
  final String? emoji;
  final String? stickerPath;
  final Offset? position;

  _PreviewData({this.emoji, this.stickerPath, this.position});
}
