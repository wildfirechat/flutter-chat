import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/pc/widgets/hover_builder.dart';

/// 桌面端二级页面统一头部栏 (高度与整体 headerHeight 保持一致)
/// 包含: 返回按钮、页面标题、可选右侧操作按钮 (actions)
class PcPageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const PcPageHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.onBack,
    this.actions,
  }) : assert(title != null || titleWidget != null);

  @override
  Size get preferredSize => const Size.fromHeight(PcTheme.headerHeight);

  PCShellViewModel? _tryGetShell(BuildContext context) {
    try {
      return Provider.of<PCShellViewModel>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
      return;
    }

    // 默认返回逻辑: 如果是在聊天 Tab 且有选中的会话，则返回到会话面板
    final shell = _tryGetShell(context);
    if (shell != null &&
        shell.selectedTab == PCShellViewModel.tabChat &&
        shell.selectedConversation != null) {
      shell.openConversation(shell.selectedConversation!);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// 返回按钮是否有去处:自定义返回始终显示;否则仅当聊天 tab 有选中会话时显示
  /// (返回可回到该会话)。其余情况下(联系人/发现/我 等 tab 打开的详情页)其正下方
  /// 就是空白占位欢迎页,返回无意义;这些 tab 的中栏列表始终可见,用户可经中栏/侧栏离开。
  bool _showBack(BuildContext context) {
    if (onBack != null) {
      return true;
    }
    final shell = _tryGetShell(context);
    return shell != null &&
        shell.selectedTab == PCShellViewModel.tabChat &&
        shell.selectedConversation != null;
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
          if (_showBack(context)) ...[
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
          ],
          Expanded(
            child: titleWidget ??
                Text(
                  title ?? '',
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
