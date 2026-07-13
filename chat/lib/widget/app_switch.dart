import 'package:flutter/material.dart';

/// 全局规范化的开关(Switch)组件。
/// 统一缩放比例（0.6）以适应界面的紧凑设计,并便于全局调整开关的大小。
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.6,
      child: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
