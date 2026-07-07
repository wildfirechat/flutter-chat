import 'package:flutter/widgets.dart';

/// 成员单元格的全局矩形,供桌面端在其上方/下方锚定弹出用户信息卡片。
/// 传入单元格自身的 BuildContext(用 Builder 包裹以拿到该子树的 RenderBox)。
/// 拿不到布局时返回 [Rect.zero],弹层会退化为按窗口边界摆放。
Rect memberCellAnchor(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) {
    return Rect.zero;
  }
  return box.localToGlobal(Offset.zero) & box.size;
}
