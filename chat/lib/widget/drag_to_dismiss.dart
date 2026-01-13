import 'package:flutter/material.dart';

class DragToDismiss extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final bool enabled;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const DragToDismiss({
    super.key,
    required this.child,
    required this.onDismiss,
    this.enabled = true,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  State<DragToDismiss> createState() => _DragToDismissState();
}

class _DragToDismissState extends State<DragToDismiss>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  double _scale = 1.0;
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _scaleAnimation;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _offsetAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(_animationController);
    _scaleAnimation =
        Tween<double>(begin: 1.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    widget.onDragStart?.call();
    setState(() {
      _isDragging = true;
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _dragOffset += details.delta;

      // Calculate scale based on drag distance
      // Dragging down scales down the image
      // Max scale down to 0.5
      double screenHeight = MediaQuery.of(context).size.height;
      double progress = (_dragOffset.dy.abs() / screenHeight).clamp(0.0, 1.0);
      _scale = (1.0 - progress * 0.5).clamp(0.5, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;

    double screenHeight = MediaQuery.of(context).size.height;
    bool shouldDismiss = _dragOffset.dy.abs() > screenHeight * 0.15 ||
        details.primaryVelocity!.abs() > 500;

    if (shouldDismiss) {
      // Animate out
      double screenHeight = MediaQuery.of(context).size.height;
      // Determine direction based on drag offset
      double endY = _dragOffset.dy > 0 ? screenHeight : -screenHeight;

      // Fade out
      setState(() {
        _isDragging = false;
      });
      _animationController.reset();
      _offsetAnimation =
          Tween<Offset>(begin: _dragOffset, end: Offset(_dragOffset.dx, endY))
              .animate(CurvedAnimation(
                  parent: _animationController, curve: Curves.linear));

      _scaleAnimation = Tween<double>(begin: _scale, end: _scale).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.linear));

      _animationController.forward().then((_) {
        widget.onDismiss();
      });
    } else {
      widget.onDragEnd?.call();
      // Snap back
      _offsetAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
          .animate(CurvedAnimation(
              parent: _animationController, curve: Curves.easeOut));
      _scaleAnimation = Tween<double>(begin: _scale, end: 1.0).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

      _animationController.reset();
      _animationController.forward().then((_) {
        setState(() {
          _dragOffset = Offset.zero;
          _scale = 1.0;
          _isDragging = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate opacity based on drag distance
    double screenHeight = MediaQuery.of(context).size.height;
    double opacity = 1.0;
    if (_isDragging || _animationController.isAnimating) {
      double progress = (_dragOffset.dy.abs() / screenHeight).clamp(0.0, 1.0);
      opacity = (1.0 - progress * 3).clamp(0.0, 1.0);
    }

    // If animating, use animation values
    Offset currentOffset = _isDragging ? _dragOffset : _offsetAnimation.value;
    double currentScale = _isDragging ? _scale : _scaleAnimation.value;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Update values during animation
        if (_animationController.isAnimating) {
          currentOffset = _offsetAnimation.value;
          currentScale = _scaleAnimation.value;

          double progress =
              (currentOffset.dy.abs() / screenHeight).clamp(0.0, 1.0);
          opacity = (1.0 - progress * 3).clamp(0.0, 1.0);
        }

        return Stack(
          children: [
            // Background
            Container(
              color: Colors.black.withValues(alpha: opacity),
            ),
            // Content
            Transform.translate(
              offset: currentOffset,
              child: Transform.scale(
                scale: currentScale,
                child: GestureDetector(
                  onVerticalDragStart:
                      widget.enabled ? _onVerticalDragStart : null,
                  onVerticalDragUpdate:
                      widget.enabled ? _onVerticalDragUpdate : null,
                  onVerticalDragEnd: widget.enabled ? _onVerticalDragEnd : null,
                  child: widget.child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
