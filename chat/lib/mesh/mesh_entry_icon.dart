import 'package:flutter/material.dart';

import '../utils/layout_scale.dart';

/// 联系人页「外部单位」入口图标:彩色圆角底 + 白色建筑图标。
///
/// 与同组的「新的朋友 / 收藏群组 / 订阅频道」一样是一块彩色圆角图标 ——
/// 那三个是 PNG 资源,外部单位没有对应资源,就地画一块同规格的。
/// 移动端与桌面端共用本件,两端只差基准尺寸,避免一端改了另一端漏改。
class MeshEntryIcon extends StatelessWidget {
  const MeshEntryIcon({super.key, required this.baseSize});

  /// 未经字号缩放的基准边长(移动端 40,桌面端 28,各自与同列其它入口图标一致)。
  final double baseSize;

  /// 与另外几张入口资源图同族的蓝。那几张是固定配色的位图,明暗主题下都不变,
  /// 这块底色跟着它们走,所以不进 AppColors 的明暗两套令牌。
  static const Color _background = Color(0xFF3098F0);

  /// 圆角比例。量自同组资源图(80px 画布上圆角半径约 7px),这样这块代码画的底
  /// 和旁边几张位图的圆角对得上 —— 原来写的 0.2 比位图圆一倍多,同列里很扎眼。
  static const double _radiusRatio = 0.09;

  @override
  Widget build(BuildContext context) {
    final size = LayoutScale.watchScale(context, baseSize);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(size * _radiusRatio),
      ),
      child: Icon(Icons.domain, size: size * 0.5, color: Colors.white),
    );
  }
}
