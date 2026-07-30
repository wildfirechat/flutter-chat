import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

/// 右栏「本栏首页」路由的名字。
///
/// 右栏的 Navigator 里,由侧栏/中栏点开的页面都是 pushAndRemoveUntil 上去的,栈里始终
/// 只有 [占位页, 该页],所以 `canPop()` 恒为真 —— 不能拿它判断"有没有上一页可回"。
/// 给这些页面打上这个名字,[PcPageHeader] 就能区分「本栏首页」(没有上一页,不显示返回键)
/// 和「在本栏里 push 出来的子页」(如组织架构 → 用户资料,要显示返回键)。
const String kPcPaneRootRoute = 'pc-pane-root';

/// 桌面端二级页面统一头部栏 (高度与整体 headerHeight 保持一致)
/// 包含: 返回按钮、页面标题、可选右侧操作按钮 (actions)
class PcPageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  /// 「无标题栏」形态:不画标题与底边,底色透出页面背景,但**仍占满 headerHeight**。
  ///
  /// 用于标题只是一个恒定名词、说不出信息的详情页(如用户资料)。不能真的把这条栏
  /// 删掉:三栏顶部(侧栏、中栏搜索栏、右栏)共用同一条 60px 水平线,右栏内容一旦顶到
  /// y=0 这条线就断了;而且返回键仍要留在这里 —— 从会话点头像卡片进用户资料时,
  /// 它是回到那个会话的唯一入口(见 [_showBack])。
  final bool bare;

  const PcPageHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.onBack,
    this.actions,
    this.bare = false,
  }) : assert(bare || title != null || titleWidget != null);

  @override
  Size get preferredSize => const Size.fromHeight(PcTheme.headerHeight);

  PCShellViewModel? _tryGetShell(BuildContext context) {
    try {
      return Provider.of<PCShellViewModel>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  /// 本页是不是在右栏里 push 出来的子页(下面还压着一个真实页面,而不是空白占位页)。
  /// 判据见 [kPcPaneRootRoute]。
  bool _hasPageBelow(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null ||
        route.isFirst ||
        route.settings.name == kPcPaneRootRoute) {
      return false;
    }
    return Navigator.of(context).canPop();
  }

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
      return;
    }

    // 本栏里 push 出来的子页:pop 回上一页(组织架构 → 用户资料,返回即回到组织架构)。
    // 用 pop 而不是 maybePop —— 后者会被页面自己的 PopScope 截走(如组织架构用它做
    // 层级内后退),那样返回键就永远离不开这一页。
    if (_hasPageBelow(context)) {
      Navigator.of(context).pop();
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

  /// 返回按钮是否有去处:自定义返回始终显示;其次是本栏里 push 出来的子页(回上一页);
  /// 再次是聊天 tab 有选中会话时(返回可回到该会话)。其余情况下(联系人/发现/我 等 tab
  /// 直接打开的详情页)其正下方就是空白占位欢迎页,返回无意义;这些 tab 的中栏列表始终
  /// 可见,用户可经中栏/侧栏离开。
  bool _showBack(BuildContext context) {
    if (onBack != null) {
      return true;
    }
    if (_hasPageBelow(context)) {
      return true;
    }
    final shell = _tryGetShell(context);
    return shell != null &&
        shell.selectedTab == PCShellViewModel.tabChat &&
        shell.selectedConversation != null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: PcTheme.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bare ? Colors.transparent : colors.surface,
        border: bare
            ? null
            : Border(bottom: BorderSide(width: 0.5, color: colors.hairline)),
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
                    color: hovered ? colors.hoverOverlay : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: bare
                ? const SizedBox.shrink()
                : titleWidget ??
                    Text(
                      title ?? '',
                      style: AppText.lg.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                          decoration: TextDecoration.none),
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
