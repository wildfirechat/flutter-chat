import 'package:flutter/material.dart';
import 'package:chat/theme/app_typography.dart';

/// 弹出菜单的面板本体：深色卡片 + 指向目标的小三角，自动避让屏幕边缘。
/// 需要铺满整屏的约束（overlay 条目或 Positioned.fill），内部按全局坐标定位。
///
/// 两条路径共用它，保证外观一致：
/// - [PopupMenuOverlay.show]：整屏遮罩 + 面板，点击别处关闭；
/// - 文本气泡内的选区菜单（SelectionArea 的 contextMenuBuilder）：不能带遮罩，
///   否则会盖住下层的选择手柄，让选区没法再调整。
class PopupMenuPanel extends StatelessWidget {
  const PopupMenuPanel({
    super.key,
    required this.targetRect,
    required this.menuItems,
    required this.onItemTap,
    this.popupWidth = 250,
    this.crossAxisCount = 4,
    this.listMode = false,
  });

  /// 菜单要指向的目标（气泡、选区）的全局矩形
  final Rect targetRect;

  /// 菜单项列表，每项包含 label, value, icon
  final List<Map<String, dynamic>> menuItems;
  final ValueChanged<String> onItemTap;

  /// 菜单宽度
  final double popupWidth;

  /// 每行显示的菜单项数量
  final int crossAxisCount;

  /// true 时竖排列表（图标+文字一行），false 时网格（图标在上文字在下）
  final bool listMode;

  static const double _padding = 10;
  static const double _arrowSize = 10;
  static const double _itemHeight = 60;
  static const double _listItemHeight = 56;
  static const double _dividerHeight = 0.5;

  /// 菜单项不足一行时,把面板收窄到刚好放下这些项(格子宽度与整屏菜单保持一致),
  /// 免得只有一两项时留出大片空白
  static double widthForItems(int itemCount, {double popupWidth = 250, int crossAxisCount = 4}) {
    if (itemCount >= crossAxisCount) {
      return popupWidth;
    }
    final double itemWidth = (popupWidth - _padding * 2) / crossAxisCount;
    return itemWidth * itemCount + _padding * 2;
  }

  @override
  Widget build(BuildContext context) {
    final double itemWidth = (popupWidth - _padding * 2) / crossAxisCount;
    final double menuHeight = listMode ? menuItems.length * _listItemHeight + (menuItems.length - 1) * _dividerHeight : (menuItems.length / crossAxisCount).ceil() * _itemHeight + _padding * 2;

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    // 可用区域的上下边界
    final double minTop = mediaQuery.padding.top + 20;
    final double maxBottom = screenSize.height - mediaQuery.padding.bottom - 20;

    // 目标元素中心点
    final double targetCenterX = targetRect.center.dx;

    // 计算菜单水平位置，确保不超出屏幕
    double left = targetCenterX - popupWidth / 2;
    if (left < 10) left = 10;
    if (left + popupWidth > screenSize.width - 10) {
      left = screenSize.width - popupWidth - 10;
    }

    // 判断菜单显示在目标上方还是下方，优先显示在上方
    bool showAbove;
    double top;

    if (targetRect.top - menuHeight - _arrowSize > minTop) {
      // 上方空间足够
      showAbove = true;
      top = targetRect.top - menuHeight - _arrowSize;
    } else if (targetRect.bottom + menuHeight + _arrowSize < maxBottom) {
      // 下方空间足够
      showAbove = false;
      top = targetRect.bottom;
    } else {
      // 都不够，选择空间更大的一侧，并确保不超出安全区域
      showAbove = targetRect.top - minTop > maxBottom - targetRect.bottom;
      if (showAbove) {
        top = targetRect.top - menuHeight - _arrowSize;
        if (top < minTop) top = minTop;
      } else {
        top = targetRect.bottom + _arrowSize;
        if (top + menuHeight > maxBottom) {
          top = maxBottom - menuHeight;
        }
      }
    }

    // 箭头位置（相对于菜单左边缘）
    double arrowLeft = targetCenterX - left;
    if (arrowLeft < 20) arrowLeft = 20;
    if (arrowLeft > popupWidth - 20) arrowLeft = popupWidth - 20;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          // 选区菜单挂在 overlay 上，没有 Material 祖先，Text 会带上 fallback 的黄色下划线
          child: Material(
            color: Colors.transparent,
            // 菜单项之间的空隙也要吃掉点击，否则会穿透到下层的消息气泡上
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!showAbove) _buildArrow(popupWidth, arrowLeft, true),
                  Container(
                    width: popupWidth,
                    padding: listMode ? EdgeInsets.zero : const EdgeInsets.all(_padding),
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
                                    height: _dividerHeight,
                                    margin: const EdgeInsets.symmetric(horizontal: 12),
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                _PopupMenuListItem(
                                  item: menuItems[i],
                                  height: _listItemHeight,
                                  onTap: () => onItemTap(menuItems[i]['value']),
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
                                onTap: () => onItemTap(item['value']),
                              );
                            }).toList(),
                          ),
                  ),
                  if (showAbove) _buildArrow(popupWidth, arrowLeft, false),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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

/// 通用弹出菜单覆盖层
/// 支持自动定位（避免超出屏幕）、小三角指示器
class PopupMenuOverlay {
  static OverlayEntry? _currentOverlay;
  static VoidCallback? _onDismiss;

  /// 关闭当前菜单
  static void dismiss() {
    if (_currentOverlay == null) {
      return;
    }
    _currentOverlay?.remove();
    _currentOverlay = null;
    final callback = _onDismiss;
    _onDismiss = null;
    callback?.call();
  }

  /// 显示菜单
  /// [context] - BuildContext
  /// [targetRect] - 目标元素的全局位置（用于定位菜单和箭头）
  /// [menuItems] - 菜单项列表，每项包含 label, value, icon
  /// [onItemTap] - 菜单项点击回调
  /// [onDismiss] - 菜单关闭时回调(点击空白、滑动关闭、点击菜单项)
  /// [popupWidth] - 菜单宽度，默认250
  /// [crossAxisCount] - 每行显示的菜单项数量，默认4
  /// [listMode] - true 时竖排列表（图标+文字一行），false 时网格（图标在上文字在下）
  static void show({
    required BuildContext context,
    required Rect targetRect,
    required List<Map<String, dynamic>> menuItems,
    required Function(String value) onItemTap,
    VoidCallback? onDismiss,
    double popupWidth = 250,
    int crossAxisCount = 4,
    bool listMode = false,
  }) {
    // 如果已有菜单，先关闭
    if (_currentOverlay != null) {
      dismiss();
      return;
    }

    final overlayState = Overlay.of(context);
    _onDismiss = onDismiss;

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
              Positioned.fill(
                child: PopupMenuPanel(
                  targetRect: targetRect,
                  menuItems: menuItems,
                  popupWidth: popupWidth,
                  crossAxisCount: crossAxisCount,
                  listMode: listMode,
                  onItemTap: (value) {
                    dismiss();
                    onItemTap(value);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    overlayState.insert(_currentOverlay!);
  }
}

class _PopupMenuItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final double width;
  final VoidCallback onTap;

  const _PopupMenuItem({
    required this.item,
    required this.width,
    required this.onTap,
  });

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
    required this.item,
    required this.height,
    required this.onTap,
  });

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
