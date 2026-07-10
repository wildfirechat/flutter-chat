import 'package:flutter/widgets.dart';

/// 分组列表之间的段间空隙(18px 占位，透明露出底层背景色)。
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 18);
  }
}
