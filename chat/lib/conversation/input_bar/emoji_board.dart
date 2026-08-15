import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/viewmodel/font_size_view_model.dart';
import 'package:chat/widgets/animated_emoji.dart';
import 'sticker_manager.dart';
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

class _EmojiBoardState extends State<EmojiBoard> {
  int _selectedIndex = 0; // 0 for Emoji, 1+ for Sticker Categories
  late PageController _pageController;
  final ScrollController _emojiScrollController = ScrollController();
  final GlobalKey _emojiGridKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  // Unified preview state
  final ValueNotifier<_PreviewData?> _previewNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    StickerManager().loadStickers().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emojiScrollController.dispose();
    _hidePreview();
    _previewNotifier.dispose();
    super.dispose();
  }

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
                  child: Image.asset(
                    data.stickerPath!,
                    gaplessPlayback: true,
                    cacheWidth: 400, // Optimize memory for preview
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

  void _updateEmojiPreview(Offset globalPosition) {
    RenderBox? renderBox =
        _emojiGridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    Offset localPosition = renderBox.globalToLocal(globalPosition);
    double width = renderBox.size.width;
    final fontSizeViewModel =
        Provider.of<FontSizeViewModel>(context, listen: false);
    final int fontIndex = fontSizeViewModel.index;
    int lineCount = 8;
    if (fontIndex == 3) {
      lineCount = 7;
    } else if (fontIndex >= 4) {
      lineCount = 6;
    }
    double cellWidth = width / lineCount;
    double cellHeight = cellWidth; // Aspect ratio 1.0

    // Adjust for padding top: 10
    double effectiveY = localPosition.dy - 10 + _emojiScrollController.offset;

    int col = (localPosition.dx / cellWidth).floor();
    int row = (effectiveY / cellHeight).floor();

    int index = row * lineCount + col;

    if (index >= 0 && index < widget.emojis.length) {
      // Calculate cell center
      double cellCenterX = (col + 0.5) * cellWidth;
      double cellCenterY =
          (row + 0.5) * cellHeight - _emojiScrollController.offset + 10;
      Offset cellCenterGlobal =
          renderBox.localToGlobal(Offset(cellCenterX, cellCenterY));

      _showEmojiPreview(cellCenterGlobal, widget.emojis[index]);
    } else {
      _hidePreview();
    }
  }

  void _hidePreview() {
    _previewNotifier.value = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    double boardHeight = widget.height ?? 280;
    final categories = StickerManager().categories;

    return Container(
      height: boardHeight,
      color: emojiBoardBackgroundColor(context),
      child: Column(
        children: [
          // Tab Bar (Top Row as requested)
          _buildTabBar(categories),
          // Content Area
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: 1 + categories.length,
              onPageChanged: (index) {
                _hidePreview();
                setState(() {
                  _selectedIndex = index;
                });
              },
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildEmojiGrid();
                } else {
                  return _buildStickerGrid(index - 1);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(List<StickerCategory> categories) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.hairline)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 1 + categories.length, // 1 for Emoji + categories
        itemBuilder: (context, index) {
          bool isSelected = _selectedIndex == index;
          return Material(
            color: isSelected
                ? (AppShell.isDesktopStyle
                    ? context.colors.chatBgDesktop
                    : context.colors.chatBg)
                : context.colors.surface,
            child: InkWell(
              onTap: () {
                _pageController.jumpToPage(index);
              },
              child: Container(
                width: 50,
                padding: const EdgeInsets.all(8),
                child: index == 0
                    ? Image.asset(
                        'assets/images/input/chat_input_bar_emoji.png')
                    : Image.asset(categories[index - 1].coverPath),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmojiGrid() {
    final fontSizeViewModel = Provider.of<FontSizeViewModel>(context);
    final fontScale = fontSizeViewModel.textScaleFactor;
    final int fontIndex = fontSizeViewModel.index;
    int lineCount = 8;
    if (fontIndex == 3) {
      lineCount = 7;
    } else if (fontIndex >= 4) {
      lineCount = 6;
    }
    double textSize = 28;
    double delSizeX = 48;
    double delSizeY = 38;
    double delPadding = 5;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 删除按钮贴在右下角,内缩量与表情格子的留白对齐。
        // 取面板自身宽度而非屏幕宽度:桌面端面板是窄弹层,用屏幕宽会把按钮推到面板中间。
        final double scaledTextSize = textSize * fontScale;
        double paddingSize =
            ((constraints.maxWidth - scaledTextSize * lineCount) /
                    lineCount /
                    2)
                .clamp(0.0, double.infinity);

        return Stack(
          children: [
            GestureDetector(
              onLongPressStart: (details) =>
                  _updateEmojiPreview(details.globalPosition),
              onLongPressMoveUpdate: (details) =>
                  _updateEmojiPreview(details.globalPosition),
              onLongPressEnd: (_) => _hidePreview(),
              child: GridView.builder(
                key: _emojiGridKey,
                controller: _emojiScrollController,
                padding: const EdgeInsets.only(top: 10, bottom: 50),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: lineCount),
                itemCount: widget.emojis.length,
                itemBuilder: (context, index) {
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () =>
                          widget.pickerEmojiCallback(widget.emojis[index]),
                      child: Center(
                        child: Text(
                          widget.emojis[index],
                          style: TextStyle(fontSize: textSize),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              right: paddingSize,
              bottom: paddingSize,
              child: GestureDetector(
                onTap: widget.delEmojiCallback,
                child: Container(
                  padding: EdgeInsets.all(delPadding),
                  decoration: BoxDecoration(
                    color: context.colors.inputBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SizedBox(
                    width: delSizeX - 2 * delPadding,
                    height: delSizeY - 2 * delPadding,
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

  Widget _buildStickerGrid(int categoryIndex) {
    final category = StickerManager().categories[categoryIndex];
    return StickerGridPage(
      stickerPaths: category.stickerPaths,
      onStickerSelected: (path) => widget.pickerStickerCallback?.call(path),
      onPreviewShow: (path) => _showStickerPreview(path),
      onPreviewHide: () => _hidePreview(),
    );
  }
}

class StickerGridPage extends StatefulWidget {
  final List<String> stickerPaths;
  final Function(String) onStickerSelected;
  final Function(String) onPreviewShow;
  final Function() onPreviewHide;

  const StickerGridPage({
    Key? key,
    required this.stickerPaths,
    required this.onStickerSelected,
    required this.onPreviewShow,
    required this.onPreviewHide,
  }) : super(key: key);

  @override
  State<StickerGridPage> createState() => _StickerGridPageState();
}

class _StickerGridPageState extends State<StickerGridPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _gridKey = GlobalKey();
  final ValueNotifier<int?> _previewingIndexNotifier = ValueNotifier(null);

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    _previewingIndexNotifier.dispose();
    super.dispose();
  }

  void _handleLongPressUpdate(Offset globalPosition) {
    RenderBox? renderBox =
        _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    Offset localPosition = renderBox.globalToLocal(globalPosition);
    double width = renderBox.size.width;

    // GridView configuration
    int crossAxisCount = 4;
    double mainAxisSpacing = 10;
    double crossAxisSpacing = 10;
    double padding = 10;

    double effectiveX = localPosition.dx - padding;
    double effectiveY = localPosition.dy - padding + _scrollController.offset;

    if (effectiveX < 0 || effectiveX > width - 2 * padding) {
      _clearPreview();
      return;
    }

    double itemWidth =
        (width - 2 * padding - (crossAxisCount - 1) * crossAxisSpacing) /
            crossAxisCount;
    double itemHeight = itemWidth; // Aspect ratio 1.0

    double strideX = itemWidth + crossAxisSpacing;
    double strideY = itemHeight + mainAxisSpacing;

    int col = (effectiveX / strideX).floor();
    int row = (effectiveY / strideY).floor();

    // Check if within item bounds (ignoring spacing gaps)
    double relativeX = effectiveX - col * strideX;
    double relativeY = effectiveY - row * strideY;

    if (col >= 0 &&
        col < crossAxisCount &&
        relativeX <= itemWidth &&
        relativeY <= itemHeight) {
      int index = row * crossAxisCount + col;
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
    return GestureDetector(
      onLongPressStart: (details) =>
          _handleLongPressUpdate(details.globalPosition),
      onLongPressMoveUpdate: (details) =>
          _handleLongPressUpdate(details.globalPosition),
      onLongPressEnd: (_) => _clearPreview(),
      child: GridView.builder(
        key: _gridKey,
        controller: _scrollController,
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: widget.stickerPaths.length,
        itemBuilder: (context, index) {
          final image = Container(
            padding: const EdgeInsets.all(5),
            child: Image.asset(
              widget.stickerPaths[index],
              cacheWidth: 200, // Optimize memory for grid
            ),
          );
          return ValueListenableBuilder<int?>(
            valueListenable: _previewingIndexNotifier,
            builder: (context, previewingIndex, child) {
              bool isPreviewing = previewingIndex == index;
              return Material(
                color: isPreviewing ? Colors.black12 : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () =>
                      widget.onStickerSelected(widget.stickerPaths[index]),
                  child: child,
                ),
              );
            },
            child: image,
          );
        },
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
