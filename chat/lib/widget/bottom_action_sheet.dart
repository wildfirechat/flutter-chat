import 'package:flutter/material.dart';

class BottomActionSheetItem {
  final String label;
  final IconData? icon;
  final Widget? leading;
  final void Function() onTap;

  BottomActionSheetItem({
    required this.label,
    this.icon,
    this.leading,
    required this.onTap,
  });
}

/// 弹出底部操作菜单 (ActionSheet)
Future<void> showBottomActionSheet({
  required BuildContext context,
  required List<BottomActionSheetItem> items,
  String? cancelLabel,
}) {
  final themeCancelLabel = cancelLabel ?? '取消';

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent, // 保证圆角剪裁区域外部透明
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F7F7), // 微信底色（灰色间隙色）
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 选项组
            Material(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          item.onTap();
                        },
                        child: SizedBox(
                          height: 64, // 增加高度以获得更好的触摸反馈体验
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (item.leading != null) ...[
                                item.leading!,
                                const SizedBox(width: 8),
                              ] else if (item.icon != null) ...[
                                Icon(item.icon, size: 22, color: Colors.black87),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                item.label,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF191919),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (index < items.length - 1)
                        const Divider(
                          height: 0.5,
                          thickness: 0.5,
                          indent: 0,
                          endIndent: 0,
                          color: Color(0xFFE5E5E5),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
            // 选项组与取消按钮之间的灰色间隙
            Container(
              height: 8,
              color: const Color(0xFFF7F7F7),
            ),
            // 取消按钮及其底部安全区（整体响应点击反馈）
            Material(
              color: Colors.white,
              child: InkWell(
                onTap: () => Navigator.pop(sheetContext),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 64, // 增加高度以获得更好的触摸反馈体验
                    child: Center(
                      child: Text(
                        themeCancelLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF191919),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
