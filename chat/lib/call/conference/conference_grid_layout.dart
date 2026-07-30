import 'package:flutter/material.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';

import 'conference_participant_item.dart';
import 'conference_participant_tile.dart';

/// PC 会议宫格布局:≤1 人 1x1、≤4 人 2x2、≤9 人 3x3,超过 9 人分页,
/// 屏幕左右边缘箭头循环翻页,底部页码指示。对齐 Electron 参考实现。
class ConferenceGridLayout extends StatefulWidget {
  /// 每页人数(3x3)。
  static const int pageSize = 9;

  /// 全部参与者(已排序)。
  final List<ConferenceParticipantItem> items;

  final bool audioOnly;

  final bool Function(ConferenceParticipantItem item) isFocusUser;
  final void Function(ConferenceParticipantItem item) onDoubleTapTile;

  /// 页码变化回调(用于大小流订阅调度)。
  final ValueChanged<int>? onPageChanged;

  const ConferenceGridLayout({
    Key? key,
    required this.items,
    required this.audioOnly,
    required this.isFocusUser,
    required this.onDoubleTapTile,
    this.onPageChanged,
  }) : super(key: key);

  @override
  State<ConferenceGridLayout> createState() => _ConferenceGridLayoutState();
}

class _ConferenceGridLayoutState extends State<ConferenceGridLayout> {
  int _currentPage = 0;

  int get _pageCount =>
      (widget.items.length + ConferenceGridLayout.pageSize - 1) ~/
      ConferenceGridLayout.pageSize;

  @override
  void didUpdateWidget(covariant ConferenceGridLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 人数减少导致页数收缩时收敛页码
    final count = _pageCount;
    if (_currentPage >= count && count > 0) {
      _goToPage(count - 1);
    }
  }

  /// 循环翻页:page 越界时取模回绕。
  void _goToPage(int page) {
    final count = _pageCount;
    if (count <= 0) return;
    final next = ((page % count) + count) % count;
    if (next == _currentPage) return;
    setState(() => _currentPage = next);
    widget.onPageChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _pageCount;
    final start = _currentPage * ConferenceGridLayout.pageSize;
    var end = start + ConferenceGridLayout.pageSize;
    if (end > widget.items.length) end = widget.items.length;
    final pageItems = start < widget.items.length
        ? widget.items.sublist(start, end)
        : <ConferenceParticipantItem>[];

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Positioned.fill(child: _buildGrid(pageItems, constraints)),
          if (pageCount > 1) ...[
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ArrowButton(
                  icon: Icons.chevron_left,
                  tooltip: AppLocalizations.of(context)!.conferencePrevPage,
                  onPressed: () => _goToPage(_currentPage - 1),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ArrowButton(
                  icon: Icons.chevron_right,
                  tooltip: AppLocalizations.of(context)!.conferenceNextPage,
                  onPressed: () => _goToPage(_currentPage + 1),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 4,
              child: Center(
                child: Text(
                  '${_currentPage + 1} / $pageCount',
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildGrid(
      List<ConferenceParticipantItem> pageItems, BoxConstraints constraints) {
    const padding = 12.0;
    const spacing = 8.0;
    final count = pageItems.length;
    if (count == 0) return const SizedBox.shrink();
    final crossAxisCount = count == 1 ? 1 : (count <= 4 ? 2 : 3);
    final rows = (count + crossAxisCount - 1) ~/ crossAxisCount;
    final cellW =
        (constraints.maxWidth - padding * 2 - spacing * (crossAxisCount - 1)) /
            crossAxisCount;
    final cellH =
        (constraints.maxHeight - padding * 2 - spacing * (rows - 1)) / rows;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(padding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: cellH > 0 ? cellW / cellH : 1.2,
      ),
      itemCount: count,
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
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 32),
      color: context.colors.textPrimary,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: context.colors.surface.withValues(alpha: 0.6),
      ),
      onPressed: onPressed,
    );
  }
}
