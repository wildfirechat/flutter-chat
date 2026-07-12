import 'package:flutter/material.dart';
import 'package:chat/theme/app_typography.dart';

/// 通用弹出菜单覆盖层
/// 支持自动定位（避免超出屏幕）、小三角指示器
class PopupMenuOverlay {
  static OverlayEntry? _currentOverlay;

  /// 关闭当前菜单
  static void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// 显示菜单
  /// [context] - BuildContext
  /// [targetRect] - 目标元素的全局位置（用于定位菜单和箭头）
  /// [menuItems] - 菜单项列表，每项包含 label, value, icon
  /// [onItemTap] - 菜单项点击回调
  /// [popupWidth] - 菜单宽度，默认250
  /// [crossAxisCount] - 每行显示的菜单项数量，默认4
  /// [listMode] - true 时竖排列表（图标+文字一行），false 时网格（图标在上文字在下）
  static void show({
    required BuildContext context,
    required Rect targetRect,
    required List<Map<String, dynamic>> menuItems,
    required Function(String value) onItemTap,
    double popupWidth = 250,
    int crossAxisCount = 4,
    bool listMode = false,
  }) {
    // 如果已有菜单，先关闭
    if (_currentOverlay != null) {
      dismiss();
      return;
    }

    const double padding = 10;
    const double arrowSize = 10;
    final double itemWidth = (popupWidth - padding * 2) / crossAxisCount;

    // 计算菜单行数和高度
    const double itemHeight = 60;
    const double listItemHeight = 56;
    const double dividerHeight = 0.5;
    final double menuHeight = listMode
        ? menuItems.length * listItemHeight +
            (menuItems.length - 1) * dividerHeight
        : (menuItems.length / crossAxisCount).ceil() * itemHeight + padding * 2;

    final overlayState = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    // 可用区域的上下边界
    final double minTop = statusBarHeight + 20;
    final double maxBottom = screenSize.height - bottomSafeArea - 20;

    // 目标元素中心点
    final double targetCenterX = targetRect.center.dx;

    // 计算菜单水平位置，确保不超出屏幕
    double left = targetCenterX - popupWidth / 2;
    if (left < 10) left = 10;
    if (left + popupWidth > screenSize.width - 10) {
      left = screenSize.width - popupWidth - 10;
    }

    // 判断菜单显示在目标上方还是下方
    // 优先显示在上方
    bool showAbove;
    double top;

    if (targetRect.top - menuHeight - arrowSize > minTop) {
      // 上方空间足够
      showAbove = true;
      top = targetRect.top - menuHeight - arrowSize;
    } else if (targetRect.bottom + menuHeight + arrowSize < maxBottom) {
      // 下方空间足够
      showAbove = false;
      //top = targetRect.bottom + arrowSize;
      top = targetRect.bottom;
    } else {
      // 都不够，选择空间更大的一侧，并确保不超出安全区域
      showAbove = targetRect.top - minTop > maxBottom - targetRect.bottom;
      if (showAbove) {
        top = targetRect.top - menuHeight - arrowSize;
        if (top < minTop) top = minTop;
      } else {
        top = targetRect.bottom + arrowSize;
        if (top + menuHeight > maxBottom) {
          top = maxBottom - menuHeight;
        }
      }
    }

    // 箭头位置（相对于菜单左边缘）
    double arrowLeft = targetCenterX - left;
    if (arrowLeft < 20) arrowLeft = 20;
    if (arrowLeft > popupWidth - 20) arrowLeft = popupWidth - 20;

    _currentOverlay = OverlayEntry(
      builder: (overlayContext) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // 透明遮罩，点击或滑动关闭菜单
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: dismiss,
                  onPanStart: (_) => dismiss(),
                  child: Container(color: Colors.transparent),
                ),
              ),
              // 菜单主体
              Positioned(
                left: left,
                top: top,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!showAbove) _buildArrow(popupWidth, arrowLeft, true),
                    Container(
                      width: popupWidth,
                      padding: listMode
                          ? EdgeInsets.zero
                          : const EdgeInsets.all(padding),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4C4C4C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: listMode
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (int i = 0; i < menuItems.length; i++) ...[
                                  if (i > 0)
                                    Container(
                                      height: dividerHeight,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      color: Colors.white
                                          .withValues(alpha: 0.12),
                                    ),
                                  _PopupMenuListItem(
                                    item: menuItems[i],
                                    height: listItemHeight,
                                    onTap: () {
                                      dismiss();
                                      onItemTap(menuItems[i]['value']);
                                    },
                                  ),
                                ],
                              ],
                            )
                          : Wrap(
                              alignment: WrapAlignment.start,
                              children: menuItems.map((item) {
                                return _PopupMenuItem(
                                  item: item,
                                  width: itemWidth,
                                  onTap: () {
                                    dismiss();
                                    onItemTap(item['value']);
                                  },
                                );
                              }).toList(),
                            ),
                    ),
                    if (showAbove) _buildArrow(popupWidth, arrowLeft, false),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    overlayState.insert(_currentOverlay!);
  }

  static Widget _buildArrow(double containerWidth, double leftOffset, bool pointUp) {
    return SizedBox(
      width: containerWidth,
      height: 10,
      child: Stack(
        children: [
          Positioned(
            left: leftOffset - 10,
            child: CustomPaint(
              size: const Size(20, 10),
              painter: _ArrowPainter(
                color: const Color(0xFF4C4C4C),
                pointUp: pointUp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopupMenuItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final double width;
  final VoidCallback onTap;

  const _PopupMenuItem({
    Key? key,
    required this.item,
    required this.width,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_PopupMenuItem> createState() => _PopupMenuItemState();
}

class _PopupMenuItemState extends State<_PopupMenuItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _isPressed ? Colors.black26 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.item['icon'], color: Colors.white, size: 24),
            const SizedBox(height: 5),
            Text(
              widget.item['label'],
              style: AppText.xs.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopupMenuListItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final double height;
  final VoidCallback onTap;

  const _PopupMenuListItem({
    Key? key,
    required this.item,
    required this.height,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_PopupMenuListItem> createState() => _PopupMenuListItemState();
}

class _PopupMenuListItemState extends State<_PopupMenuListItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: _isPressed ? Colors.black26 : Colors.transparent,
        child: Row(
          children: [
            Icon(widget.item['icon'], color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.item['label'],
                style: AppText.base.copyWith(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  final bool pointUp;

  _ArrowPainter({required this.color, required this.pointUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (pointUp) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.close();
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
