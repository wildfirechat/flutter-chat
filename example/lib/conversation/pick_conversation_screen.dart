import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/home/conversation_list_widget.dart';
import 'package:wfc_example/viewmodel/conversation_list_view_model.dart';

class PickConversationScreen extends StatefulWidget {
  final Function(BuildContext context, Conversation conversation)? onConversationSelected;
  const PickConversationScreen({Key? key, this.onConversationSelected}) : super(key: key);

  @override
  State<PickConversationScreen> createState() => _PickConversationScreenState();
}

class _PickConversationScreenState extends State<PickConversationScreen> {
  @override
  Widget build(BuildContext context) {
    var conversationListViewModel = Provider.of<ConversationListViewModel>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择会话'),
      ),
      body: SafeArea(
        child: ListView.builder(
            itemCount: conversationListViewModel.conversationList.length,
            itemExtent: 64.5,
            key: ValueKey<int>(conversationListViewModel.conversationList.length),
            itemBuilder: (context, i) {
              ConversationInfo info = conversationListViewModel.conversationList[i];
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
