import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 下拉退出预览(参考微信):
/// - 图片双轴跟随手指移动;
/// - 下拉时以手指位置为锚点缩小(手指按住的图像点始终贴着手指);
/// - 上拉不缩小、不退出,松手回弹;
/// - 下拉超过阈值或快速下滑时退出,背景随下拉距离渐隐;
/// - 退出时若能拿到来源缩略图的 rect,内容飞回并收敛裁剪到该 rect
///   (缩回消息气泡的效果),否则下滑滑出屏幕。
class DragToDismiss extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final bool enabled;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  /// 内容(当前预览媒体)静止时的屏幕显示区域,飞回动画以它计算几何
  final Rect Function()? contentRect;

  /// 退出目标(来源缩略图)的全局 rect;返回 null 退化为下滑退出
  final Rect? Function()? dismissTargetRect;

  const DragToDismiss({
    super.key,
    required this.child,
    required this.onDismiss,
    this.enabled = true,
    this.onDragStart,
    this.onDragEnd,
    this.contentRect,
    this.dismissTargetRect,
  });

  @override
  State<DragToDismiss> createState() => _DragToDismissState();
}

class _DragToDismissState extends State<DragToDismiss>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero; // 手指相对拖拽起点的位移(双轴)
  double _scale = 1.0;
  Offset _anchor = Offset.zero; // 缩放锚点:手指按下处(child 坐标系)
  Offset _dragStartGlobal = Offset.zero;
  bool _isDragging = false;

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Animation<Offset>? _offsetAnimation;
  Animation<double>? _scaleAnimation;
  // 飞回目标时:屏幕空间裁剪 rect(内容边界 → 目标气泡 rect)与背景透明度
  Animation<Rect?>? _clipAnimation;
  Animation<double>? _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController.addListener(() {
      if (_offsetAnimation == null) return;
      setState(() {
        _dragOffset = _offsetAnimation!.value;
        _scale = _scaleAnimation!.value;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double get _screenHeight => MediaQuery.of(context).size.height;

  // 只有下拉(dy > 0)才缩小/减淡,上拉保持原样
  double get _downProgress => (_dragOffset.dy / _screenHeight).clamp(0.0, 1.0);

  void _onVerticalDragStart(DragStartDetails details) {
    _animationController.stop();
    _animationController.duration = const Duration(milliseconds: 200);
    _offsetAnimation = null;
    _scaleAnimation = null;
    _clipAnimation = null;
    _opacityAnimation = null;

    // 半途接住回弹动画:换锚点时补偿位移,保证画面连续
    final Offset newAnchor = details.localPosition;
    _dragOffset += (_anchor - newAnchor) * (1.0 - _scale);
    _anchor = newAnchor;
    _dragStartGlobal = details.globalPosition - _dragOffset;

    widget.onDragStart?.call();
    setState(() {
      _isDragging = true;
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragOffset = details.globalPosition - _dragStartGlobal;
      _scale = 1.0 - _downProgress * 0.5;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final double velocityY = details.primaryVelocity ?? 0.0;
    final bool shouldDismiss =
        _dragOffset.dy > _screenHeight * 0.15 || velocityY > 500;

    if (shouldDismiss) {
      final Rect? target = widget.dismissTargetRect?.call();
      if (target != null && widget.contentRect != null) {
        _startDismissToTarget(widget.contentRect!(), target);
        return;
      }
      _offsetAnimation = Tween<Offset>(
        begin: _dragOffset,
        end: Offset(_dragOffset.dx, _screenHeight),
      ).animate(CurvedAnimation(
          parent: _animationController, curve: Curves.easeOut));
      _scaleAnimation =
          Tween<double>(begin: _scale, end: _scale).animate(_animationController);
      _animationController.forward(from: 0).then((_) {
        widget.onDismiss();
      });
    } else {
      widget.onDragEnd?.call();
      _offsetAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
          .animate(CurvedAnimation(
              parent: _animationController, curve: Curves.easeOut));
      _scaleAnimation = Tween<double>(begin: _scale, end: 1.0).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
      _animationController.forward(from: 0);
    }
    setState(() {});
  }

  // 当前变换(offset + 以 anchor 为锚的 scale)下,child 坐标 → 屏幕坐标
  Offset _mapPoint(Offset p) => _dragOffset + _anchor + (p - _anchor) * _scale;

  Rect _mapRect(Rect r) =>
      Rect.fromPoints(_mapPoint(r.topLeft), _mapPoint(r.bottomRight));

  // 屏幕坐标 rect → child 坐标(裁剪用,随动画每帧换算)
  Rect _toChildRect(Rect screenRect) {
    Offset invert(Offset p) => (p - _dragOffset - _anchor) / _scale + _anchor;
    return Rect.fromPoints(
        invert(screenRect.topLeft), invert(screenRect.bottomRight));
  }

  // 飞回来源缩略图:内容以 cover 比例缩到目标中心,屏幕空间裁剪从
  // 当前内容边界收敛到目标 rect(圆角 8,与气泡一致),背景同步淡出
  void _startDismissToTarget(Rect content, Rect globalTarget) {
    // 目标是全局坐标;预览路由全屏时与本组件坐标一致,仍换算一次以防万一
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect target = box == null
        ? globalTarget
        : Rect.fromPoints(box.globalToLocal(globalTarget.topLeft),
            box.globalToLocal(globalTarget.bottomRight));

    final double endScale = math.max(
        target.width / content.width, target.height / content.height);
    final Offset endOffset =
        target.center - _anchor - (content.center - _anchor) * endScale;

    final CurvedAnimation curved = CurvedAnimation(
        parent: _animationController, curve: Curves.easeOutCubic);
    _offsetAnimation =
        Tween<Offset>(begin: _dragOffset, end: endOffset).animate(curved);
    _scaleAnimation =
        Tween<double>(begin: _scale, end: endScale).animate(curved);
    _clipAnimation =
        RectTween(begin: _mapRect(content), end: target).animate(curved);
    _opacityAnimation = Tween<double>(
            begin: (1.0 - _downProgress * 1.5).clamp(0.0, 1.0), end: 0.0)
        .animate(curved);

    _animationController.duration = const Duration(milliseconds: 260);
    _animationController.forward(from: 0).then((_) {
      widget.onDismiss();
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final double opacity = _opacityAnimation?.value ??
        (1.0 - _downProgress * 1.5).clamp(0.0, 1.0);

    // 以手指按下处为锚点缩放,再叠加手指位移:锚点处的图像点始终跟着手指走
    final Matrix4 transform = Matrix4.identity()
      ..translateByDouble(
          _dragOffset.dx + _anchor.dx, _dragOffset.dy + _anchor.dy, 0, 1)
      ..scaleByDouble(_scale, _scale, 1, 1)
      ..translateByDouble(-_anchor.dx, -_anchor.dy, 0, 1);

    Widget content = GestureDetector(
      onVerticalDragStart: widget.enabled ? _onVerticalDragStart : null,
      onVerticalDragUpdate: widget.enabled ? _onVerticalDragUpdate : null,
      onVerticalDragEnd: widget.enabled ? _onVerticalDragEnd : null,
      child: widget.child,
    );

    // 飞回目标时逐帧裁剪:屏幕空间的裁剪 rect 换算回 child 坐标,
    // 圆角保持屏幕 8(除以 scale 抵消变换),落点形状与气泡缩略图一致。
    // ClipRRect 必须常驻(不裁剪时 Clip.none),否则中途插入会改变树结构,
    // 导致 PageView 子树被重建、页码跳回 initialPage
    final Rect? screenClip = _clipAnimation?.value;
    content = ClipRRect(
      clipper: screenClip == null
          ? null
          : _RRectClipper(_toChildRect(screenClip), 8.0 / _scale),
      clipBehavior: screenClip == null ? Clip.none : Clip.antiAlias,
      child: content,
    );

    return Stack(
      children: [
        // Background
        Container(
          color: Colors.black.withValues(alpha: opacity),
        ),
        // Content
        Transform(
          transform: transform,
          child: content,
        ),
      ],
    );
  }
}

class _RRectClipper extends CustomClipper<RRect> {
  final Rect rect;
  final double radius;

  const _RRectClipper(this.rect, this.radius);

  @override
  RRect getClip(Size size) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  bool shouldReclip(_RRectClipper oldClipper) =>
      rect != oldClipper.rect || radius != oldClipper.radius;
}
