import 'dart:ui';

import 'package:flutter/material.dart';
import 'sticker_manager.dart';

typedef OnPickerEmojiCallback = void Function(String emoji);
typedef OnDelEmojiCallback = void Function();
typedef OnPickerStickerCallback = void Function(String stickerPath);

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
    _previewNotifier.value = _PreviewData(emoji: emoji, position: cellCenterGlobal);
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
            // Emoji Preview
            return Positioned(
              left: data.position!.dx - 30,
              top: data.position!.dy - 100,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Text(data.emoji!, style: const TextStyle(fontSize: 36)),
                    ),
                    CustomPaint(
                      size: const Size(12, 8),
                      painter: _TrianglePainter(Colors.white),
                    ),
                  ],
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
                    color: Colors.white,
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
    RenderBox? renderBox = _emojiGridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    Offset localPosition = renderBox.globalToLocal(globalPosition);
    double width = renderBox.size.width;
    int lineCount = 8;
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
      double cellCenterY = (row + 0.5) * cellHeight - _emojiScrollController.offset + 10;
      Offset cellCenterGlobal = renderBox.localToGlobal(Offset(cellCenterX, cellCenterY));
      
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
      color: const Color(0xFFF5F5F5),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 1 + categories.length, // 1 for Emoji + categories
        itemBuilder: (context, index) {
          bool isSelected = _selectedIndex == index;
          return Material(
            color: isSelected ? const Color(0xFFF5F5F5) : Colors.white,
            child: InkWell(
              onTap: () {
                _pageController.jumpToPage(index);
              },
              child: Container(
                width: 50,
                padding: const EdgeInsets.all(8),
                child: index == 0
                    ? Image.asset('assets/images/input/chat_input_bar_emoji.png')
                    : Image.asset(categories[index - 1].coverPath),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmojiGrid() {
    int lineCount = 8;
    double screenWidth = MediaQuery.of(context).size.width;
    double textSize = 28;
    double paddingSize = (screenWidth - textSize * lineCount) / lineCount / 2;
    double delSizeX = 48;
    double delSizeY = 38;
    double delPadding = 5;

    return Stack(
      children: [
        GestureDetector(
          onLongPressStart: (details) => _updateEmojiPreview(details.globalPosition),
          onLongPressMoveUpdate: (details) => _updateEmojiPreview(details.globalPosition),
          onLongPressEnd: (_) => _hidePreview(),
          child: GridView.builder(
            key: _emojiGridKey,
            controller: _emojiScrollController,
            padding: const EdgeInsets.only(top: 10, bottom: 50),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: lineCount),
            itemCount: widget.emojis.length,
            itemBuilder: (context, index) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.pickerEmojiCallback(widget.emojis[index]),
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
                color: const Color.fromARGB(255, 232, 232, 232),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SizedBox(
                width: delSizeX - 2 * delPadding,
                height: delSizeY - 2 * delPadding,
                child: Image.asset('assets/images/input/del_emoji.png'),
              ),
            ),
          ),
        )
      ],
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

class _StickerGridPageState extends State<StickerGridPage> with AutomaticKeepAliveClientMixin {
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
    RenderBox? renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
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

    double itemWidth = (width - 2 * padding - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;
    double itemHeight = itemWidth; // Aspect ratio 1.0

    double strideX = itemWidth + crossAxisSpacing;
    double strideY = itemHeight + mainAxisSpacing;

    int col = (effectiveX / strideX).floor();
    int row = (effectiveY / strideY).floor();

    // Check if within item bounds (ignoring spacing gaps)
    double relativeX = effectiveX - col * strideX;
    double relativeY = effectiveY - row * strideY;

    if (col >= 0 && col < crossAxisCount && relativeX <= itemWidth && relativeY <= itemHeight) {
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
      onLongPressStart: (details) => _handleLongPressUpdate(details.globalPosition),
      onLongPressMoveUpdate: (details) => _handleLongPressUpdate(details.globalPosition),
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
                  onTap: () => widget.onStickerSelected(widget.stickerPaths[index]),
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