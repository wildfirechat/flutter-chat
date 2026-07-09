import 'package:flutter/material.dart';

import 'package:chat/theme/app_colors.dart';
import 'package:chat/widget/portrait.dart';

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
              Portrait(portrait, defaultPortrait, width: 42, height: 42, borderRadius: 4.0),
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
                      border: Border.all(color: context.colors.hairline, width: 0.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2),
                      ],
                    ),
                    child: Icon(Icons.close, size: 10, color: context.colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(fontSize: 12, color: context.colors.textPrimary, decoration: TextDecoration.none),
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
        child: Portrait(portrait, defaultPortrait, width: 30, height: 30, borderRadius: 4.0),
      ),
    );
  }
}
