import 'package:flutter/material.dart';

/// 桌面端锚定弹层:优先出现在锚点上方(输入栏工具条在窗口底部),
/// 空间不足时翻转到下方;点击外部或 Esc 关闭。
Future<T?> showPcPopover<T>({
  required BuildContext context,
  required Rect anchor,
  required Size size,
  required WidgetBuilder builder,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    _PcPopoverRoute<T>(anchor: anchor, size: size, builder: builder),
  );
}

class _PcPopoverRoute<T> extends PopupRoute<T> {
  final Rect anchor;
  final Size size;
  final WidgetBuilder builder;

  _PcPopoverRoute({required this.anchor, required this.size, required this.builder});

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'popover';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return CustomSingleChildLayout(
      delegate: _PcPopoverLayoutDelegate(anchor: anchor, size: size),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: Material(
          color: Colors.white,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: SizedBox.fromSize(size: size, child: Builder(builder: builder)),
        ),
      ),
    );
  }
}

class _PcPopoverLayoutDelegate extends SingleChildLayoutDelegate {
  final Rect anchor;
  final Size size;

  static const double _margin = 8;

  _PcPopoverLayoutDelegate({required this.anchor, required this.size});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints.tight(size);

  @override
  Offset getPositionForChild(Size parentSize, Size childSize) {
    double x = anchor.left - 8;
    x = x.clamp(_margin, parentSize.width - childSize.width - _margin);

    double y = anchor.top - childSize.height - _margin;
    if (y < _margin) {
      y = anchor.bottom + _margin;
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PcPopoverLayoutDelegate oldDelegate) => anchor != oldDelegate.anchor || size != oldDelegate.size;
}
