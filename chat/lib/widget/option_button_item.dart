import 'package:flutter/material.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/theme/app_colors.dart';
import '../utils/layout_scale.dart';

class OptionButtonItem extends StatelessWidget {
  final String title;

  /// 不传则用主题的危险色(删除/退出这类操作)。默认值不能写成 `Colors.red` ——
  /// 那是编译期常量,跟不了明暗主题。
  final Color? titleColor;
  final bool showBottomDivider;
  final GestureTapCallback onTap;

  const OptionButtonItem(this.title, this.onTap, {this.showBottomDivider = true, this.titleColor, super.key});

  @override
  Widget build(BuildContext context) {
    final btnHeight = LayoutScale.watchScale(context, 32.0, cap: LayoutScale.rowCap);
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
              constraints: BoxConstraints(minHeight: btnHeight),
              child: Center(
                  child: Text(
                title,
                style: TextStyle(color: titleColor ?? context.colors.danger),
              )),
            ),
          ),
        ),
        // 桌面端行间不画线,与 OptionItem 保持一致。
        if (showBottomDivider && !isDesktopShell)
          Container(
            height: 0.5,
            color: context.colors.hairline,
          ),
      ],
    );
  }
}
