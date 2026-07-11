import 'package:badges/badges.dart' as badge;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 未读数气泡。
///
/// badges 包默认使用 [badge.BadgeShape.circle],圆形徽标的直径取内容盒的最短边:
/// 单个数字("1")按宽度收缩成小圆,而 "99+" 变宽后按高度撑成大圆,于是同一列表
/// 里徽标高度参差不齐。
///
/// 这里改为固定高度的圆角气泡——单个数字近似圆形,数字变多时自动变成椭圆 / 圆角
/// 长方形,但高度始终一致。移动端与 PC 端共用。
class UnreadBadge extends StatelessWidget {
  /// >0 显示数字(超过 99 显示 "99+"); ==-1 或 [asDot] 为 true 时显示小红点;
  /// ==0 时不显示徽标。
  final int count;

  /// 强制以小红点样式显示(例如免打扰会话有未读时)。
  final bool asDot;

  /// 徽标叠加的目标控件;为 null 时只返回徽标本身。
  final Widget? child;

  /// 徽标相对 [child] 的位置,为 null 时用 badges 包默认的右上角。
  final badge.BadgePosition? position;

  final double fontSize;
  final double height;
  final double dotSize;

  const UnreadBadge({
    super.key,
    required this.count,
    this.child,
    this.asDot = false,
    this.position,
    this.fontSize = 12,
    this.height = 18,
    this.dotSize = 10,
  });

  bool get _asDot => asDot || count == -1;

  Widget _buildContent(BuildContext context) {
    final color = context.colors.badge;
    if (_asDot) {
      return Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    return Container(
      height: height,
      // 单个数字时宽度不小于高度,保持正圆;数字变多时自动横向拉长成圆角长方形。
      constraints: BoxConstraints(minWidth: height),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          height: 1.0,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // badges 包只负责把徽标定位到 child 的角上;背景与形状全部由 _buildContent
    // 自绘,所以这里把它自带的背景设为透明、padding 归零。
    return badge.Badge(
      showBadge: count != 0,
      position: position,
      badgeStyle: const badge.BadgeStyle(
        shape: badge.BadgeShape.square,
        padding: EdgeInsets.zero,
        badgeColor: Colors.transparent,
        elevation: 0,
      ),
      badgeContent: _buildContent(context),
      child: child,
    );
  }
}
