import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/search/search_portal_result_view.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 搜索浮层内容(参照微信 PC):
/// 头部原位替换为聚焦态的真输入框,结果以圆角浮起卡片悬于列表上方,
/// 其余区域透出底下的中栏内容;Esc 或点击外部关闭。
/// 根节点透明,由 PCHome 以透明 modal 路由承载。
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 头部:与常规中栏头部同构且保持中栏宽度(原位覆盖),
          // 面板整体比中栏宽,头部右侧的空白区域透出右栏、点击走 barrier 关闭
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: PcTheme.middleColumnWidth,
              height: PcTheme.headerHeight,
              color: PcTheme.middleBg,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.only(left: 8, right: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: PcTheme.accent, width: 1.2),
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
                          if (_query.isNotEmpty)
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  _controller.clear();
                                  setState(() => _query = '');
                                },
                                child: const Icon(Icons.cancel, size: 14, color: PcTheme.textTertiary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 占位的“+”,维持与常规头部一致的布局(不可交互)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: PcTheme.searchFieldBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.add, size: 18, color: const Color(0xFF5C5C5C).withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
          ),
          // 结果卡片:圆角浮起,越过中栏、部分悬于右栏之上;无关键词时不显示
          Expanded(
            child: _query.isEmpty
                ? const SizedBox.shrink()
                : Container(
                    margin: const EdgeInsets.fromLTRB(8, 2, 8, 12),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SearchPortalResultView(
                      _query,
                      key: const ValueKey('pc-search-result'),
                      onUserSelected: widget.onUserSelected,
                      onConversationSelected: widget.onConversationSelected,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
