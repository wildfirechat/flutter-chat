import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/search/conversation_search_panel.dart';

/// 会话内「查找聊天内容」手机页：AppBar 只留标题，搜索框与分类标签在面板内。
class SearchConversationResultView extends StatelessWidget {
  final Conversation conversation;
  final String keyword;

  const SearchConversationResultView({
    super.key,
    required this.conversation,
    required this.keyword,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.searchChatContents),
      ),
      body: ConversationSearchPanel(
        conversation,
        initialKeyword: keyword,
      ),
    );
  }
}
