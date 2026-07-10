import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'package:chat/settings/file_records_screen.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/widget/section_divider.dart';

/// PC 中栏使用的文件入口列表。
///
/// 与移动端 [FileRecordsScreen] 不同,这里不带 [Scaffold]/[AppBar],直接嵌入中栏,
/// 点击分类后通过 [onOpenFileList] 回调在右栏打开具体文件列表;
/// 需要选择会话/用户的分类通过 [onOpenConversationPicker]/[onOpenUserPicker] 回调,
/// 由父组件决定把选择页放到右栏,避免覆盖整个窗口。
class PcFileRecordsList extends StatelessWidget {
  final void Function(FileListScreen screen) onOpenFileList;
  final VoidCallback onOpenConversationPicker;
  final VoidCallback onOpenUserPicker;

  const PcFileRecordsList({
    super.key,
    required this.onOpenFileList,
    required this.onOpenConversationPicker,
    required this.onOpenUserPicker,
  });

  void _openList(BuildContext context, String title, FileListType type,
      {Conversation? conversation, String? userId}) {
    onOpenFileList(FileListScreen(
      title: title,
      type: type,
      conversation: conversation,
      userId: userId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Column(
        children: [
          OptionItem(
            l10n.allFiles,
            onTap: () => _openList(context, l10n.allFiles, FileListType.all),
          ),
          const SectionDivider(),
          OptionItem(
            l10n.myFiles,
            onTap: () => _openList(context, l10n.myFiles, FileListType.my),
          ),
          const SectionDivider(),
          OptionItem(
            l10n.chatFiles,
            onTap: onOpenConversationPicker,
          ),
          const SectionDivider(),
          OptionItem(
            l10n.userFiles,
            onTap: onOpenUserPicker,
          ),
          const SectionDivider(),
        ],
      ),
    );
  }
}
