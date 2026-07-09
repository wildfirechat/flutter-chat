import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:chat/pc/pc_theme.dart';
import 'package:chat/theme/app_colors.dart';

/// 弹层相对锚点的水平对齐方式。
enum PcPopoverAlign {
  /// 左缘对齐锚点左缘(略微左移让出内边距)。
  start,

  /// 水平居中于锚点。面板远宽于按钮时会向两侧溢出,可以压到左侧栏上方,
  /// 微信 PC 的表情面板即此形态。
  center,
}

/// 桌面端锚定弹层:优先出现在锚点上方(输入栏工具条在窗口底部),
/// 空间不足时翻转到下方;点击外部或 Esc 关闭。
///
/// 宽度由调用方给定,高度由内容决定(上限为 [maxHeight] 与可视区域中的较小者),
/// 调用方因此不必为内容维护一份魔法高度。
Future<T?> showPcPopover<T>({
  required BuildContext context,
  required Rect anchor,
  required double width,
  double? maxHeight,
  PcPopoverAlign align = PcPopoverAlign.start,
  required WidgetBuilder builder,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    _PcPopoverRoute<T>(anchor: anchor, width: width, maxHeight: maxHeight, align: align, builder: builder),
  );
}

class _PcPopoverRoute<T> extends PopupRoute<T> {
  final Rect anchor;
  final double width;
  final double? maxHeight;
  final PcPopoverAlign align;
  final WidgetBuilder builder;

  _PcPopoverRoute({
    required this.anchor,
    required this.width,
    this.maxHeight,
    required this.align,
    required this.builder,
  });

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
      delegate: _PcPopoverLayoutDelegate(anchor: anchor, width: width, maxHeight: maxHeight, align: align),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        // 弹层挂在 root navigator 上,不在 PC 子树内,主题要在这里补回来。
        child: Theme(
          data: PcTheme.themeData(context),
          child: Material(
            color: context.colors.popupBg,
            // 卡片压在聊天区上:阴影拉开纵深,再用一道极淡的边收住轮廓。
            elevation: 12,
            shadowColor: context.colors.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: context.colors.hairlineSoft),
            ),
            clipBehavior: Clip.antiAlias,
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
  }
}

class _PcPopoverLayoutDelegate extends SingleChildLayoutDelegate {
  final Rect anchor;
  final double width;
  final double? maxHeight;
  final PcPopoverAlign align;

  static const double _margin = 8;

  _PcPopoverLayoutDelegate({required this.anchor, required this.width, this.maxHeight, required this.align});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.min(maxHeight ?? double.infinity, constraints.maxHeight - _margin * 2),
    );
  }

  @override
  Offset getPositionForChild(Size parentSize, Size childSize) {
    double x = switch (align) {
      PcPopoverAlign.start => anchor.left - 8,
      PcPopoverAlign.center => anchor.center.dx - childSize.width / 2,
    };
    x = x.clamp(_margin, parentSize.width - childSize.width - _margin);

    double y = anchor.top - childSize.height - _margin;
    if (y < _margin) {
      y = anchor.bottom + _margin;
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PcPopoverLayoutDelegate oldDelegate) =>
      anchor != oldDelegate.anchor ||
      width != oldDelegate.width ||
      maxHeight != oldDelegate.maxHeight ||
      align != oldDelegate.align;
}
