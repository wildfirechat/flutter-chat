import 'package:flutter/material.dart';

import 'package:chat/config.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/workspace/workspace_tabs_view_model.dart';

/// 工作台自己的头部页签栏(仅桌面)。
///
/// 高度取 [PcTheme.headerHeight],与侧栏、中栏搜索栏共用顶部那条 60px 水平线。
class WorkspaceTabBar extends StatelessWidget {
  const WorkspaceTabBar({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onSelect,
    required this.onClose,
    this.onOpenDevTools,
  });

  final List<WorkspaceTab> tabs;
  final String activeTabId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;

  /// 打开当前页签的开发者工具。入口由 [Config.ENABLE_WEBVIEW_DEVTOOLS] 控制
  /// —— 工作台是远端 H5,出问题基本都要看它自己的 console。
  final VoidCallback? onOpenDevTools;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: PcTheme.headerHeight,
      decoration: BoxDecoration(
        color: colors.sectionGap,
        border: Border(bottom: BorderSide(width: 0.5, color: colors.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final tab in tabs)
                    _WorkspaceTabItem(
                      key: ValueKey(tab.id),
                      tab: tab,
                      selected: tab.id == activeTabId,
                      onSelect: () => onSelect(tab.id),
                      onClose: () => onClose(tab.id),
                    ),
                ],
              ),
            ),
          ),
          if (Config.ENABLE_WEBVIEW_DEVTOOLS && onOpenDevTools != null)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 6),
              child: HoverBuilder(
                cursor: SystemMouseCursors.click,
                builder: (context, hovered) => GestureDetector(
                  onTap: onOpenDevTools,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: hovered ? colors.hoverOverlay : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.bug_report_outlined,
                      size: 16,
                      color: colors.iconSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceTabItem extends StatelessWidget {
  const _WorkspaceTabItem({
    super.key,
    required this.tab,
    required this.selected,
    required this.onSelect,
    required this.onClose,
  });

  final WorkspaceTab tab;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  /// 首页页签只放标题,其余按内容伸缩但不超过这个宽度。
  static const double _maxWidth = 180;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final title = tab.closable
        ? (tab.title?.isNotEmpty == true ? tab.title! : l10n.loading)
        : l10n.tabWork;

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onSelect,
        child: Container(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          height: 34,
          margin: const EdgeInsets.only(right: 2),
          padding: EdgeInsets.only(left: 12, right: tab.closable ? 4 : 12),
          decoration: BoxDecoration(
            color: selected
                ? colors.surface
                : (hovered ? colors.hoverOverlay : Colors.transparent),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.base.copyWith(
                    color: selected ? colors.textPrimary : colors.textSecondary,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
              if (tab.closable) ...[
                const SizedBox(width: 4),
                // 关闭键常驻而不是 hover 才出现:hover 才出现会让页签宽度跳变,
                // 且原生 WebView 盖在下方时鼠标事件的边界本就不直观。
                HoverBuilder(
                  cursor: SystemMouseCursors.click,
                  builder: (context, closeHovered) => GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: closeHovered
                            ? colors.hoverOverlay
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: colors.iconSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
