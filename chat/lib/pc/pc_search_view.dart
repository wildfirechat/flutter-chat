import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/search/search_portal_result_view.dart';
import 'package:chat/l10n/app_localizations.dart';

/// 搜索浮层内容(参照微信 PC):
/// 头部原位替换为聚焦态的真输入框,结果以圆角浮起卡片悬于列表上方,
/// 其余区域透出底下的中栏内容;Esc 或点击外部关闭。
/// 根节点透明,由 PCHome 以透明 modal 路由承载。
class PcSearchView extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(String userId) onUserSelected;
  final void Function(Conversation conversation, {int? focusMessageId}) onConversationSelected;

  /// 头部要与它盖住的中栏头部同宽(中栏宽度用户可拖拽调整),由 PCHome 传入。
  final double middleColumnWidth;

  const PcSearchView({
    super.key,
    required this.middleColumnWidth,
    required this.onClose,
    required this.onUserSelected,
    required this.onConversationSelected,
  });

  @override
  State<PcSearchView> createState() => _PcSearchViewState();
}

class _PcSearchViewState extends State<PcSearchView> {
  /// 输入框(28高)在 60 高的头部里垂直居中,下沿离头部底还有 16px 空白。
  /// 结果卡片上提盖住这段空白,使其紧随输入框下方。
  static const double _resultOverlap = 10;
  static const double _cardTopGap = 2;
  static const double _cardBottomMargin = 12;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isFocused = _focusNode.hasFocus;
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头部:与常规中栏头部同构且保持中栏宽度(原位覆盖),
          // 面板整体比中栏宽,头部右侧的空白区域透出右栏、点击走 barrier 关闭
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: widget.middleColumnWidth,
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
                              focusNode: _focusNode,
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
          // 上提盖住头部下沿的空白,卡片紧随输入框
          Transform.translate(
            offset: const Offset(0, -_resultOverlap),
            child: _buildBody(context, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_query.isEmpty) {
      if (!_isFocused) {
        return const SizedBox.shrink();
      }
      return _buildCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Center(
            child: Text(
              l10n.searchPrompt,
              style: const TextStyle(
                fontSize: 13,
                color: PcTheme.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final maxContentHeight =
        screenHeight - PcTheme.headerHeight + _resultOverlap - _cardTopGap - _cardBottomMargin;

    return _buildCard(
      constraints: BoxConstraints(maxHeight: maxContentHeight),
      child: SearchPortalResultView(
        _query,
        key: const ValueKey('pc-search-result'),
        shrinkWrap: true,
        onUserSelected: widget.onUserSelected,
        onConversationSelected: widget.onConversationSelected,
      ),
    );
  }

  Widget _buildCard({required Widget child, BoxConstraints? constraints}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, _cardTopGap, 8, _cardBottomMargin),
      constraints: constraints,
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
      child: child,
    );
  }
}
