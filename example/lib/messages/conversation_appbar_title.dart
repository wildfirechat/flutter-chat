import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/viewmodel/conversation_view_model.dart';

class ConversationAppbarTitle extends StatelessWidget {
  const ConversationAppbarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<ConversationViewModel, String>(
      builder: (_, title, __) {
        return Text(title);
      },
      selector: (_, viewModel) => viewModel.conversationTitle,
    );
  }
}
