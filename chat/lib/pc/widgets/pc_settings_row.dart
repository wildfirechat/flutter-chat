import 'package:flutter/material.dart';

import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/widget/app_switch.dart';

/// PC 设置页的分节标题(从 pc_settings_page.dart 抽取共享,
/// 供隐私子页面等与主设置页保持一致的字体样式)。
class PcSettingsSectionTitle extends StatelessWidget {
  final String title;
  const PcSettingsSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppText.xs.copyWith(
            fontWeight: FontWeight.w600, color: context.colors.textSecondary),
      ),
    );
  }
}

/// PC 设置页的开关行(标题 + 副标题 + AppSwitch)。
class PcSettingsSwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const PcSettingsSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.base.copyWith(
                        fontWeight: FontWeight.w500,
                        color: context.colors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppText.xs
                        .copyWith(color: context.colors.textSecondary)),
              ],
            ),
          ),
          AppSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// PC 设置页的点击跳转行(标题 + 副标题 + 右箭头,悬停高亮)。
class PcSettingsClickableRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const PcSettingsClickableRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) {
        return InkWell(
          onTap: onTap,
          child: Container(
            color: hovered ? context.colors.hoverOverlay : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppText.base.copyWith(
                              fontWeight: FontWeight.w500,
                              color: context.colors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: AppText.xs
                              .copyWith(color: context.colors.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: context.colors.textTertiary),
              ],
            ),
          ),
        );
      },
    );
  }
}
