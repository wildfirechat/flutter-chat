import 'package:flutter/material.dart';

import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/utils/layout_scale.dart';

/// PC 中栏的入口行:点一下在右栏打开对应页面(收藏分类、文件入口)。
///
/// 形态跟通讯录中栏的入口行:整行铺满、不切圆角。选中仍是灰底([AppColors.cellSelected])——
/// 主题色的整行选中目前只留给会话列表(设置菜单是另一套圆角胶囊,不走这里)。
///
/// 和 OptionItem 分工:OptionItem 是**信息/设置行**,桌面端刻意不做 hover,
/// 可点性由鼠标指针交代;入口行是中栏的主操作,必须有 hover 与选中态 ——
/// 否则桌面上既看不出这行可点,也看不出右栏当前停在哪一项。
class PcNavCell extends StatelessWidget {
  final String title;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  /// 与通讯录子行同高,中栏各 tab 切换时行高不跳。
  static const double _rowHeight = 52;

  const PcNavCell({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Color background(bool hovered) {
      if (selected) return colors.cellSelected;
      if (hovered) return colors.cellHover;
      return Colors.transparent;
    }

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: LayoutScale.watchScale(context, _rowHeight,
              cap: LayoutScale.rowCap),
          color: background(hovered),
          padding: const EdgeInsets.only(left: 16, right: 14),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: LayoutScale.watchScale(context, 20,
                      cap: LayoutScale.iconCap),
                  // 选中态是灰底,图标染主题色、文字加粗来点明当前项(与设置菜单同一处理)。
                  color: selected ? colors.accent : colors.iconSecondary,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PcTheme.cellTitle(context)
                      .copyWith(fontWeight: selected ? FontWeight.w500 : null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
