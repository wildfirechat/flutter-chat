import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/home/conversation_list_widget.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';

import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/l10n/app_localizations.dart';

class PickConversationScreen extends StatefulWidget {
  final Function(BuildContext context, Conversation conversation)?
      onConversationSelected;
  final VoidCallback? onBack;
  const PickConversationScreen(
      {Key? key, this.onConversationSelected, this.onBack})
      : super(key: key);

  @override
  State<PickConversationScreen> createState() => _PickConversationScreenState();
}

class _PickConversationScreenState extends State<PickConversationScreen> {
  @override
  Widget build(BuildContext context) {
    var conversationListViewModel =
        Provider.of<ConversationListViewModel>(context);
    final title = AppLocalizations.of(context)!.selectConversations;
    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: title,
              onBack: widget.onBack,
            )
          : AppBar(
              title: Text(title),
            ),
      body: SafeArea(
        child: ListView.builder(
            itemCount: conversationListViewModel.conversationList.length,
            itemExtent: LayoutScale.watchScale(context, kConversationRowHeight,
                    cap: LayoutScale.rowCap) +
                0.5,
            key: ValueKey<int>(
                conversationListViewModel.conversationList.length),
            itemBuilder: (context, i) {
              ConversationInfo info =
                  conversationListViewModel.conversationList[i];
              var key =
                  '${info.conversation.conversationType}-${info.conversation.target}-${info.conversation.conversationType}-${info.conversation.line}-${info.timestamp}';
              return ConversationListItem(
                info,
                key: ValueKey(key),
                onTap: (conversation) {
                  if (widget.onConversationSelected != null) {
                    widget.onConversationSelected!(context, conversation);
                  } else {
                    Navigator.pop(context, conversation);
                  }
                },
              );
            }),
      ),
    );
  }
}
