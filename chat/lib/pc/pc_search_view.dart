import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/search/search_portal_result_view.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 中栏内联搜索(参照微信 PC):顶部搜索输入框 + 下方实时结果,
/// 不再全窗口 push SearchDelegate。Esc 或“取消”退出。
class PcSearchView extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(String userId) onUserSelected;
  final void Function(Conversation conversation, {int? focusMessageId}) onConversationSelected;

  const PcSearchView({
    super.key,
    required this.onClose,
    required this.onUserSelected,
    required this.onConversationSelected,
  });

  @override
  State<PcSearchView> createState() => _PcSearchViewState();
}

class _PcSearchViewState extends State<PcSearchView> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          Container(
            height: PcTheme.headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: PcTheme.searchFieldBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 15, color: PcTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            autofocus: true,
                            style: const TextStyle(fontSize: 13, color: PcTheme.textPrimary),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: l10n.search,
                              hintStyle: const TextStyle(fontSize: 13, color: PcTheme.textSecondary),
                            ),
                            onChanged: (text) => setState(() => _query = text.trim()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Text(l10n.cancel, style: const TextStyle(fontSize: 13, color: PcTheme.accent)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? const SizedBox.shrink()
                : SearchPortalResultView(
                    _query,
                    // 用 key 让 query 变化时保持同一个 State(其内部实时 search)
                    key: const ValueKey('pc-search-result'),
                    onUserSelected: widget.onUserSelected,
                    onConversationSelected: widget.onConversationSelected,
                  ),
          ),
        ],
      ),
    );
  }
}
