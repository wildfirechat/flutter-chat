import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/settings/file_records_screen.dart';

/// 会话文件记录页：复用 [FileListScreen]/[FileListWidget]，
/// 与设置里的文件记录共享分页、搜索、打开与删除逻辑。
class ConversationFilesScreen extends StatelessWidget {
  final Conversation conversation;

  const ConversationFilesScreen(this.conversation, {super.key});

  @override
  Widget build(BuildContext context) {
    return FileListScreen(
      title: AppLocalizations.of(context)!.chatFiles,
      onBack: () => Navigator.of(context).maybePop(),
      type: FileListType.conversation,
      conversation: conversation,
    );
  }
}
