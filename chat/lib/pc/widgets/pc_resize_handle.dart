import 'package:flutter/material.dart';

import 'package:chat/pc/pc_theme.dart';
import 'package:chat/theme/app_colors.dart';

/// 分隔条的拖拽方向。
enum PcResizeAxis {
  /// 竖直分隔条,左右拖动调整两侧栏宽度。
  horizontal,

  /// 水平分隔条,上下拖动调整上下区域高度。
  vertical,
}

/// 桌面端可拖拽分隔条:命中区加厚到 [PcTheme.resizeHandleThickness] 方便鼠标抓取,
/// 视觉仍只有贴边的一道 0.5 发丝线(位置由 [lineAlignment] 指定),
/// 悬停时线条加深、拖拽中高亮为品牌色,并切换成对应方向的调整光标。
///
/// 命中区透明:它会盖住身后 [thickness] 宽的内容,所以要放在能被盖的一侧
/// (如右栏左缘),而不是挤在两栏之间——后者会把发丝线推离相邻的滚动条。
///
/// 本组件只负责手势与视觉,不持有尺寸:调用方在 [onDragDelta] 里按位移增量
/// 算出新尺寸写进布局状态,并在 [onDragEnd] 里持久化。
class PcResizeHandle extends StatefulWidget {
  const PcResizeHandle({
    super.key,
    required this.axis,
    required this.lineAlignment,
    required this.onDragStart,
    required this.onDragDelta,
    required this.onDragEnd,
    this.thickness = PcTheme.resizeHandleThickness,
  });

  final PcResizeAxis axis;

  /// 发丝线在命中区内贴哪条边,如 [Alignment.centerLeft]、[Alignment.topCenter]。
  final Alignment lineAlignment;

  final VoidCallback onDragStart;

  /// 沿拖拽方向的位移增量,向右/向下为正。
  final ValueChanged<double> onDragDelta;

  final VoidCallback onDragEnd;

  final double thickness;

  @override
  State<PcResizeHandle> createState() => _PcResizeHandleState();
}

class _PcResizeHandleState extends State<PcResizeHandle> {
  bool _hovered = false;
  bool _dragging = false;

  bool get _isHorizontal => widget.axis == PcResizeAxis.horizontal;

  Color get _lineColor {
    final colors = context.colors;
    if (_dragging) {
      return colors.accent;
    }
    return _hovered ? colors.resizeHandleHover : colors.hairline;
  }

  void _onDragStart(DragStartDetails details) {
    setState(() => _dragging = true);
    widget.onDragStart();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    widget.onDragDelta(details.primaryDelta ?? 0);
  }

  // 同时用作 onXxxDragEnd(DragEndDetails) 与 onXxxDragCancel(无参)
  void _onDragEnd([DragEndDetails? details]) {
    if (_dragging) {
      setState(() => _dragging = false);
    }
    widget.onDragEnd();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _isHorizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _isHorizontal ? _onDragStart : null,
        onHorizontalDragUpdate: _isHorizontal ? _onDragUpdate : null,
        onHorizontalDragEnd: _isHorizontal ? _onDragEnd : null,
        onHorizontalDragCancel: _isHorizontal ? _onDragEnd : null,
        onVerticalDragStart: _isHorizontal ? null : _onDragStart,
        onVerticalDragUpdate: _isHorizontal ? null : _onDragUpdate,
        onVerticalDragEnd: _isHorizontal ? null : _onDragEnd,
        onVerticalDragCancel: _isHorizontal ? null : _onDragEnd,
        child: SizedBox(
          width: _isHorizontal ? widget.thickness : double.infinity,
          height: _isHorizontal ? double.infinity : widget.thickness,
          child: Align(
            alignment: widget.lineAlignment,
            child: SizedBox(
              width: _isHorizontal ? 0.5 : double.infinity,
              height: _isHorizontal ? double.infinity : 0.5,
              child: ColoredBox(color: _lineColor),
            ),
          ),
        ),
      ),
    );
  }
}
