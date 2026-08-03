import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 消息气泡外形:圆角矩形 + 指向发送者头像的小尾巴(微信形态)。
///
/// 尾巴画在靠头像的一侧:己方消息在右,对方消息在左。
/// [dimensions] 把尾巴宽度让给正文做内边距,所以只要把本 shape 交给
/// `ShapeDecoration.shape`,`Container` 会自动把内容从尾巴上挪开,
/// 各 cell_builder 不用关心尾巴的存在。
@immutable
class BubbleTailBorder extends ShapeBorder {
  const BubbleTailBorder({
    required this.tailOnRight,
    this.radius = 8.0,
    this.tailWidth = defaultTailWidth,
    this.tailHeight = 14.0,
    this.tailTop = 11.0,
  });

  /// 尾巴的默认长度。气泡外面要跟气泡本体对齐的元素(如气泡下面的引用行)
  /// 得把这一档让出来,所以单列成常量。
  static const double defaultTailWidth = 6.0;

  /// true 尾巴在右侧(己方发出),false 在左侧(对方发来)。
  final bool tailOnRight;

  /// 气泡本体的圆角半径。
  final double radius;

  /// 尾巴从气泡本体伸出的长度。
  final double tailWidth;

  /// 尾巴根部贴在气泡边上的高度。
  final double tailHeight;

  /// 尾巴根部顶端距气泡顶边的距离,尖端大致对着头像上半部分。
  final double tailTop;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(
        left: tailOnRight ? 0 : tailWidth,
        right: tailOnRight ? tailWidth : 0,
      );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    // 气泡本体:整块区域挖掉尾巴占的那一条
    final body = Rect.fromLTRB(
      rect.left + (tailOnRight ? 0 : tailWidth),
      rect.top,
      rect.right - (tailOnRight ? tailWidth : 0),
      rect.bottom,
    );
    final bodyPath = Path()
      ..addRRect(RRect.fromRectAndRadius(body, Radius.circular(radius)));
    if (body.isEmpty || body.height < tailHeight + radius) {
      // 气泡矮到放不下尾巴(理论上不会,minHeight 44),退化成纯圆角矩形
      return bodyPath;
    }

    // 尾巴根部整体不超过圆角起始处,避免尖端斜插在圆角上
    final top = body.top + math.min(tailTop, body.height - tailHeight - radius);
    // 朝气泡外的方向:右侧尾巴为 +1,左侧为 -1
    final dir = tailOnRight ? 1.0 : -1.0;
    final edgeX = tailOnRight ? body.right : body.left;
    // 根部往本体内埋半个像素,union 后不会在接缝处留下抗锯齿细线
    final rootX = edgeX - dir * 0.5;
    final tipX = edgeX + dir * tailWidth;

    final tailPath = Path()
      ..moveTo(rootX, top)
      ..quadraticBezierTo(
        edgeX + dir * tailWidth * 0.55,
        top + tailHeight * 0.12,
        tipX,
        top + tailHeight * 0.52,
      )
      ..quadraticBezierTo(
        edgeX + dir * tailWidth * 0.5,
        top + tailHeight * 0.78,
        rootX,
        top + tailHeight,
      )
      ..close();

    return Path.combine(PathOperation.union, bodyPath, tailPath);
  }

  /// 气泡没有描边,填充由 `ShapeDecoration.color` 负责,这里无需绘制。
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => BubbleTailBorder(
        tailOnRight: tailOnRight,
        radius: radius * t,
        tailWidth: tailWidth * t,
        tailHeight: tailHeight * t,
        tailTop: tailTop * t,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BubbleTailBorder &&
        other.tailOnRight == tailOnRight &&
        other.radius == radius &&
        other.tailWidth == tailWidth &&
        other.tailHeight == tailHeight &&
        other.tailTop == tailTop;
  }

  @override
  int get hashCode =>
      Object.hash(tailOnRight, radius, tailWidth, tailHeight, tailTop);
}
