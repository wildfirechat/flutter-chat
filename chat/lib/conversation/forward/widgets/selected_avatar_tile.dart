import 'package:flutter/material.dart';

import 'package:chat/theme/app_colors.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/theme/app_typography.dart';

/// 已选目标的方格:头像 + 右上角删除按钮 + 名称。用于桌面端右栏。
class SelectedAvatarTile extends StatelessWidget {
  final String portrait;
  final String defaultPortrait;
  final String name;
  final VoidCallback onRemove;

  const SelectedAvatarTile({
    super.key,
    required this.portrait,
    required this.defaultPortrait,
    required this.name,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Portrait(portrait, defaultPortrait,
                  width: 42, height: 42, borderRadius: 4.0),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: context.colors.popupBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: context.colors.hairline, width: 0.5),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2),
                      ],
                    ),
                    child: Icon(Icons.close,
                        size: 10, color: context.colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: AppText.xs.copyWith(
                color: context.colors.textPrimary,
                decoration: TextDecoration.none),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 搜索框里内联的已选头像,点击即取消选择。用于移动端。
class PortraitChip extends StatelessWidget {
  final String portrait;
  final String defaultPortrait;
  final VoidCallback onTap;

  const PortraitChip({
    super.key,
    required this.portrait,
    required this.defaultPortrait,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Portrait(portrait, defaultPortrait,
            width: 30, height: 30, borderRadius: 4.0),
      ),
    );
  }
}

/// 已选目标的垂直行:头像 + 名称 + 右侧删除按钮。用于桌面端右栏。
class SelectedListTile extends StatelessWidget {
  final String portrait;
  final String defaultPortrait;
  final String name;
  final VoidCallback onRemove;

  const SelectedListTile({
    super.key,
    required this.portrait,
    required this.defaultPortrait,
    required this.name,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onRemove,
        child: Container(
          height:
              LayoutScale.watchScale(context, 48.0, cap: LayoutScale.rowCap),
          color: hovered ? context.colors.hoverOverlay : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Portrait(portrait, defaultPortrait,
                  width: 30, height: 30, borderRadius: 4.0),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: AppText.sm.copyWith(
                      color: context.colors.textPrimary,
                      decoration: TextDecoration.none),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.remove_circle_outline,
                size: LayoutScale.watchScale(context, 18.0,
                    cap: LayoutScale.iconCap),
                color: hovered
                    ? context.colors.badge
                    : context.colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
