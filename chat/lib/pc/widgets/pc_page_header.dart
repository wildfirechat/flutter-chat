import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/pc/widgets/hover_builder.dart';

/// 桌面端二级页面统一头部栏 (高度与整体 headerHeight 保持一致)
/// 包含: 返回按钮、页面标题、可选右侧操作按钮 (actions)
class PcPageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const PcPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(PcTheme.headerHeight);

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
      return;
    }

    // 默认返回逻辑: 如果是在聊天 Tab 且有选中的会话，则返回到会话面板
    final shell = Provider.of<PCShellViewModel>(context, listen: false);
    if (shell.selectedTab == PCShellViewModel.tabChat && shell.selectedConversation != null) {
      shell.openConversation(shell.selectedConversation!);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: PcTheme.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(width: 0.5, color: PcTheme.hairline)),
      ),
      child: Row(
        children: [
          HoverBuilder(
            cursor: SystemMouseCursors.click,
            builder: (context, hovered) => GestureDetector(
              onTap: () => _handleBack(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: hovered ? Colors.black.withValues(alpha: 0.04) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: PcTheme.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: PcTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
