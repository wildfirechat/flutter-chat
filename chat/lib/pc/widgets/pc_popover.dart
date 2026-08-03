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

/// 弹层落在锚点的哪一侧。
enum PcPopoverPlacement {
  /// 优先上方,空间不足翻到下方。
  auto,
  above,
  below,
}

/// 尾巴从卡片伸出的长度(同时是卡片给尾巴让出的内边距)。
const double _kTailHeight = 7;

/// 尾巴根部的宽度。
const double _kTailWidth = 16;

/// 桌面端锚定弹层:优先出现在锚点上方(输入栏工具条在窗口底部),
/// 空间不足时翻转到下方;点击外部或 Esc 关闭。
///
/// 宽度由调用方给定,高度由内容决定(上限为 [maxHeight] 与可视区域中的较小者),
/// 调用方因此不必为内容维护一份魔法高度。
///
/// [tail] 为 true 时卡片朝锚点一侧长出一个指向性小三角(微信预览卡片形态)。
/// 尾巴的横向位置由本文件按锚点中心算,方向必须和落位一致,所以此时
/// [placement] 不能是 auto —— 调用方自己判断上方放不放得下(它才知道内容高度)。
Future<T?> showPcPopover<T>({
  required BuildContext context,
  required Rect anchor,
  required double width,
  double? maxHeight,
  PcPopoverAlign align = PcPopoverAlign.start,
  PcPopoverPlacement placement = PcPopoverPlacement.auto,
  bool tail = false,
  required WidgetBuilder builder,
}) {
  assert(!tail || placement != PcPopoverPlacement.auto,
      '带尾巴的浮层要指定 above/below,否则尾巴方向可能和落位相反');
  return Navigator.of(context, rootNavigator: true).push<T>(
    _PcPopoverRoute<T>(
        anchor: anchor,
        width: width,
        maxHeight: maxHeight,
        align: align,
        placement: placement,
        tail: tail,
        builder: builder),
  );
}

class _PcPopoverRoute<T> extends PopupRoute<T> {
  final Rect anchor;
  final double width;
  final double? maxHeight;
  final PcPopoverAlign align;
  final PcPopoverPlacement placement;
  final bool tail;
  final WidgetBuilder builder;

  _PcPopoverRoute({
    required this.anchor,
    required this.width,
    this.maxHeight,
    required this.align,
    required this.placement,
    required this.tail,
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
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    const double radius = 8;
    final side = BorderSide(color: context.colors.hairlineSoft);
    // 尾巴朝锚点:卡片在上方就朝下。方向由 placement 定死(见 showPcPopover 的注释)。
    final bool pointsDown = placement == PcPopoverPlacement.above;
    // 尾巴对准锚点中心。卡片左缘用和 delegate 同一套算法,两边落位才一致。
    final double tailCenterX = anchor.center.dx -
        _PcPopoverLayoutDelegate.leftOf(
            anchor: anchor,
            align: align,
            width: width,
            parentWidth: MediaQuery.sizeOf(context).width);

    Widget content = Builder(builder: builder);
    if (tail) {
      // Material 不会把 shape.dimensions 当内边距用,尾巴那条得自己让出来。
      content = Padding(
        padding: EdgeInsets.only(
          top: pointsDown ? 0 : _kTailHeight,
          bottom: pointsDown ? _kTailHeight : 0,
        ),
        child: content,
      );
    }

    return CustomSingleChildLayout(
      delegate: _PcPopoverLayoutDelegate(
          anchor: anchor,
          width: width,
          maxHeight: maxHeight,
          align: align,
          placement: placement,
          // 带尾巴时卡片要贴着锚点,让尾尖落在锚点边上
          gap: tail ? 2 : _PcPopoverLayoutDelegate._margin),
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
            shape: tail
                ? _PcPopoverTailBorder(
                    radius: radius,
                    side: side,
                    tailCenterX: tailCenterX,
                    pointsDown: pointsDown,
                  )
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                    side: side,
                  ),
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// 浮层外形:圆角矩形 + 朝锚点的小三角。三角画在卡片让出的那条边距里,
/// 和本体合成一条路径,阴影和描边才是连续的。
@immutable
class _PcPopoverTailBorder extends ShapeBorder {
  const _PcPopoverTailBorder({
    required this.radius,
    required this.side,
    required this.tailCenterX,
    required this.pointsDown,
  });

  final double radius;
  final BorderSide side;

  /// 尾尖在卡片内的横坐标(卡片左缘为 0),会被夹到圆角之外。
  final double tailCenterX;

  /// true 尾巴长在底边朝下(卡片在锚点上方)。
  final bool pointsDown;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(
        top: pointsDown ? 0 : _kTailHeight,
        bottom: pointsDown ? _kTailHeight : 0,
      );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    // 本体:整块区域挖掉尾巴占的那一条
    final body = Rect.fromLTRB(
      rect.left,
      rect.top + (pointsDown ? 0 : _kTailHeight),
      rect.right,
      rect.bottom - (pointsDown ? _kTailHeight : 0),
    );
    final bodyPath = Path()
      ..addRRect(RRect.fromRectAndRadius(body, Radius.circular(radius)));
    if (body.isEmpty || body.width < (radius + _kTailWidth) * 2) {
      return bodyPath;
    }

    final double cx = rect.left +
        tailCenterX.clamp(
            radius + _kTailWidth / 2, body.width - radius - _kTailWidth / 2);
    final double dir = pointsDown ? 1 : -1;
    // 根部往本体内埋半个像素,union 后接缝处不留抗锯齿细线
    final double baseY = (pointsDown ? body.bottom : body.top) - dir * 0.5;
    final double tipY = baseY + dir * _kTailHeight;

    final tailPath = Path()
      ..moveTo(cx - _kTailWidth / 2, baseY)
      // 尖端收一个小圆角,不然在浅色底上会显得扎眼
      ..lineTo(cx - 2, tipY - dir * 1.5)
      ..quadraticBezierTo(cx, tipY, cx + 2, tipY - dir * 1.5)
      ..lineTo(cx + _kTailWidth / 2, baseY)
      ..close();

    return Path.combine(PathOperation.union, bodyPath, tailPath);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) {
      return;
    }
    canvas.drawPath(
      getOuterPath(rect, textDirection: textDirection),
      side.toPaint()..style = PaintingStyle.stroke,
    );
  }

  @override
  ShapeBorder scale(double t) => _PcPopoverTailBorder(
        radius: radius * t,
        side: side.scale(t),
        tailCenterX: tailCenterX * t,
        pointsDown: pointsDown,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _PcPopoverTailBorder &&
        other.radius == radius &&
        other.side == side &&
        other.tailCenterX == tailCenterX &&
        other.pointsDown == pointsDown;
  }

  @override
  int get hashCode => Object.hash(radius, side, tailCenterX, pointsDown);
}

class _PcPopoverLayoutDelegate extends SingleChildLayoutDelegate {
  final Rect anchor;
  final double width;
  final double? maxHeight;
  final PcPopoverAlign align;
  final PcPopoverPlacement placement;

  /// 卡片与锚点之间留的空隙。带尾巴时几乎贴上去,尾尖才能落在锚点边上。
  final double gap;

  static const double _margin = 8;

  _PcPopoverLayoutDelegate(
      {required this.anchor,
      required this.width,
      this.maxHeight,
      required this.align,
      required this.placement,
      required this.gap});

  /// 卡片左缘。尾巴要对准锚点,得先知道卡片落在哪,所以单独抽出来共用。
  static double leftOf({
    required Rect anchor,
    required PcPopoverAlign align,
    required double width,
    required double parentWidth,
  }) {
    final double x = switch (align) {
      PcPopoverAlign.start => anchor.left - 8,
      PcPopoverAlign.center => anchor.center.dx - width / 2,
    };
    final double maxX = parentWidth - width - _margin;
    return maxX <= _margin ? _margin : x.clamp(_margin, maxX);
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.min(
          maxHeight ?? double.infinity, constraints.maxHeight - _margin * 2),
    );
  }

  @override
  Offset getPositionForChild(Size parentSize, Size childSize) {
    final double x = leftOf(
        anchor: anchor,
        align: align,
        width: childSize.width,
        parentWidth: parentSize.width);

    final bool above = switch (placement) {
      PcPopoverPlacement.above => true,
      PcPopoverPlacement.below => false,
      PcPopoverPlacement.auto => anchor.top - childSize.height - gap >= _margin,
    };
    double y =
        above ? anchor.top - childSize.height - gap : anchor.bottom + gap;
    // 落位被指定时也不能顶出窗口(锚点贴边、内容又高)
    final double maxY = parentSize.height - childSize.height - _margin;
    y = maxY <= _margin ? _margin : y.clamp(_margin, maxY);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PcPopoverLayoutDelegate oldDelegate) =>
      anchor != oldDelegate.anchor ||
      width != oldDelegate.width ||
      maxHeight != oldDelegate.maxHeight ||
      align != oldDelegate.align ||
      placement != oldDelegate.placement ||
      gap != oldDelegate.gap;
}
