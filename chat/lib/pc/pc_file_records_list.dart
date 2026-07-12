import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'package:chat/pc/widgets/pc_nav_cell.dart';
import 'package:chat/settings/file_records_screen.dart';

/// PC 中栏使用的文件入口列表。
///
/// 与移动端 [FileRecordsScreen] 不同,这里不带 [Scaffold]/[AppBar],直接嵌入中栏,
/// 点击分类后通过 [onOpenFileList] 回调在右栏打开具体文件列表;
/// 需要选择会话/用户的分类通过 [onOpenConversationPicker]/[onOpenUserPicker] 回调,
/// 由父组件决定把选择页放到右栏,避免覆盖整个窗口。
///
/// 选中态只存在本地:切走 tab 时本组件被销毁,而 pc_home 也同时清空了右栏,两边一起复位。
class PcFileRecordsList extends StatefulWidget {
  final void Function(FileListScreen screen) onOpenFileList;
  final VoidCallback onOpenConversationPicker;
  final VoidCallback onOpenUserPicker;

  const PcFileRecordsList({
    super.key,
    required this.onOpenFileList,
    required this.onOpenConversationPicker,
    required this.onOpenUserPicker,
  });

  @override
  State<PcFileRecordsList> createState() => _PcFileRecordsListState();
}

class _PcFileRecordsListState extends State<PcFileRecordsList> {
  int? _selected;

  void _select(int index, VoidCallback open) {
    setState(() {
      _selected = index;
    });
    open();
  }

  void _openList(String title, FileListType type, {Conversation? conversation, String? userId}) {
    widget.onOpenFileList(FileListScreen(
      title: title,
      type: type,
      conversation: conversation,
      userId: userId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = <(String, VoidCallback)>[
      (l10n.allFiles, () => _openList(l10n.allFiles, FileListType.all)),
      (l10n.myFiles, () => _openList(l10n.myFiles, FileListType.my)),
      (l10n.chatFiles, widget.onOpenConversationPicker),
      (l10n.userFiles, widget.onOpenUserPicker),
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          for (final (index, (title, open)) in entries.indexed)
            PcNavCell(
              title: title,
              selected: _selected == index,
              onTap: () => _select(index, open),
            ),
        ],
      ),
    );
  }
}
