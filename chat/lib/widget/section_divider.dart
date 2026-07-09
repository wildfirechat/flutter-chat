import 'package:flutter/cupertino.dart';

import 'package:chat/theme/app_colors.dart';

/// 分组列表之间的段间凹槽(18px 横带)。
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      width: View.of(context).physicalSize.width,
      color: context.colors.sectionGap,
    );
  }
}
