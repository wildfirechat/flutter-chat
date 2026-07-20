import 'package:flutter/material.dart';
import 'package:chat/widget/page_dots_indicator.dart';

import 'conference_focus_page.dart';
import 'conference_participant_item.dart';
import 'conference_participant_tile.dart';

/// 移动端会议布局(唯一一种):横向 PageView,第 0 页为焦点大画面,
/// 第 1..n 页为 2x2 网格(每页 4 人,自己排第一格,由调用方排序保证)。
/// 对齐 iOS/Android 参考:≤2 人时只有焦点页,>2 人时页数 = 1 + ceil(n/4)。
class ConferenceMobileLayout extends StatefulWidget {
  /// 全部参与者(已排序,自己排第一位)。
  final List<ConferenceParticipantItem> items;

  /// 焦点用户(第 0 页大画面)。
  final ConferenceParticipantItem? focusItem;

  /// 焦点页右上角预览小窗显示的用户(通常是自己),null 表示不显示。
  final ConferenceParticipantItem? previewItem;

  final bool audioOnly;

  /// 当前焦点 userId。发生变化(主持人设焦点/有人开始共享等)时自动滑回第 0 页。
  final String? focusKey;

  final bool Function(ConferenceParticipantItem item) isFocusUser;
  final void Function(ConferenceParticipantItem item) onDoubleTapTile;

  /// 双人时点击预览小窗交换焦点。
  final VoidCallback? onSwapPreview;

  /// 页码变化回调(用于大小流订阅调度)。
  final ValueChanged<int>? onPageChanged;

  const ConferenceMobileLayout({
    Key? key,
    required this.items,
    required this.focusItem,
    required this.previewItem,
    required this.audioOnly,
    required this.focusKey,
    required this.isFocusUser,
    required this.onDoubleTapTile,
    this.onSwapPreview,
    this.onPageChanged,
  }) : super(key: key);

  @override
  State<ConferenceMobileLayout> createState() => _ConferenceMobileLayoutState();
}

class _ConferenceMobileLayoutState extends State<ConferenceMobileLayout> {
  static const int _gridPageSize = 4;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  int get _pageCount => widget.items.length <= 2
      ? 1
      : 1 + ((widget.items.length + _gridPageSize - 1) ~/ _gridPageSize);

  @override
  void didUpdateWidget(covariant ConferenceMobileLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 焦点变化 → 自动回第 0 页(双击网格设焦点/主持人设焦点/共享开始共用此路径)
    if (widget.focusKey != oldWidget.focusKey &&
        widget.focusKey != null &&
        _currentPage != 0) {
      _animateTo(0);
    }
    // 人数减少导致页数收缩时收敛页码
    final count = _pageCount;
    if (_currentPage >= count) {
      _animateTo(count - 1);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateTo(int page) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _pageCount;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: pageCount,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              widget.onPageChanged?.call(page);
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return ConferenceFocusPage(
                  focusItem: widget.focusItem,
                  previewItem: widget.previewItem,
                  audioOnly: widget.audioOnly,
                  isFocusUser: widget.isFocusUser,
                  onSwapPreview:
                      widget.items.length == 2 ? widget.onSwapPreview : null,
                  onDoubleTapTile: widget.onDoubleTapTile,
                );
              }
              return _buildGridPage(index);
            },
          ),
        ),
        PageDotsIndicator(pageCount: pageCount, currentPage: _currentPage),
      ],
    );
  }

  /// 第 pageIndex(>=1)个网格页:2x2,每页 4 人。
  Widget _buildGridPage(int pageIndex) {
    final start = (pageIndex - 1) * _gridPageSize;
    var end = start + _gridPageSize;
    if (end > widget.items.length) end = widget.items.length;
    final pageItems = widget.items.sublist(start, end);

    return LayoutBuilder(builder: (context, constraints) {
      const padding = 8.0;
      const spacing = 8.0;
      final cellW = (constraints.maxWidth - padding * 2 - spacing) / 2;
      final cellH = (constraints.maxHeight - padding * 2 - spacing) / 2;
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(padding),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: cellH > 0 ? cellW / cellH : 1,
        ),
        itemCount: pageItems.length,
        itemBuilder: (context, index) {
          final item = pageItems[index];
          return ConferenceParticipantTile(
            item: item,
            audioOnly: widget.audioOnly,
            isFocusUser: widget.isFocusUser(item),
            onDoubleTap: () => widget.onDoubleTapTile(item),
          );
        },
      );
    });
  }
}
