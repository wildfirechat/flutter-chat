import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/collection_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'package:chat/pc/widgets/pc_dialog.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/widget/app_bar_actions.dart';
import '../widget/portrait.dart';
import 'collection_model.dart';
import 'collection_service.dart';
import 'package:chat/app_shell.dart';

/// 接龙详情:接龙内容 + 参与清单,自己那条可就地编辑。
///
/// 清空自己的内容再提交即退出接龙(与 Android 一致),故提交按钮的文案是「提交」而非「参与」。
class CollectionDetailScreen extends StatefulWidget {
  final Message message;
  final bool asDialog;

  const CollectionDetailScreen(
      {super.key, required this.message, this.asDialog = false});

  static Future<void> show(BuildContext context, Message message) {
    if (AppShell.isDesktopStyle) {
      return showPcDialog(
        context: context,
        width: 460,
        height: 620,
        builder: (_) =>
            CollectionDetailScreen(message: message, asDialog: true),
      );
    }
    return Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CollectionDetailScreen(message: message)),
    );
  }

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  late CollectionMessageContent messageContent;
  late int collectionId;
  late String groupId;
  late String currentUserId;

  Collection? collection;
  bool isLoading = true;
  bool hasJoined = false;
  String? myEntryContent;

  final TextEditingController _editController = TextEditingController();
  String? _originalContent;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    messageContent = widget.message.content as CollectionMessageContent;
    collectionId = int.tryParse(messageContent.collectionId) ?? 0;
    groupId = widget.message.conversation.target;
    currentUserId = Imclient.currentUserId;

    _fetchCollectionDetail();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _fetchCollectionDetail() async {
    if (!CollectionService.isAvailable) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final result =
          await CollectionService.getCollection(collectionId, groupId);
      if (!mounted) return;
      setState(() {
        collection = result;
        isLoading = false;
        _updateJoinStatus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      Fluttertoast.showToast(msg: '${_l10n.collectionLoadFailed}: $e');
    }
  }

  void _updateJoinStatus() {
    if (collection == null) return;

    hasJoined = false;
    myEntryContent = null;

    for (final entry in collection!.validEntries) {
      if (currentUserId == entry.userId) {
        hasJoined = true;
        myEntryContent = entry.content;
        break;
      }
    }

    if (hasJoined && myEntryContent != null) {
      _editController.text = myEntryContent!;
      _originalContent = myEntryContent;
    } else {
      _editController.clear();
      _originalContent = '';
    }
  }

  /// 未参与:有内容才能提交;已参与:内容变了才能提交(清空 = 退出接龙)。
  bool get _canSubmit {
    if (collection == null || !collection!.isJoinable) return false;

    final current = _editController.text.trim();

    if (hasJoined) {
      if (current.isEmpty) {
        return myEntryContent?.isNotEmpty ?? false;
      }
      return current != _originalContent;
    }
    return current.isNotEmpty;
  }

  Future<void> _onSubmit() async {
    if (!CollectionService.isAvailable) {
      Fluttertoast.showToast(msg: _l10n.collectionServiceNotConfigured);
      return;
    }

    final content = _editController.text.trim();

    if (hasJoined) {
      if (content.isEmpty) {
        _confirmDeleteEntry();
      } else {
        await _submitEntry(content,
            successMsg: _l10n.collectionUpdateSuccess,
            failedMsg: _l10n.collectionUpdateFailed);
      }
      return;
    }

    if (content.isEmpty) {
      Fluttertoast.showToast(msg: _l10n.collectionJoinHint);
      return;
    }
    await _submitEntry(content,
        successMsg: _l10n.collectionJoinSuccess,
        failedMsg: _l10n.collectionJoinFailed);
  }

  /// 参与与修改是同一个接口,只有提示语不同。
  Future<void> _submitEntry(String content,
      {required String successMsg, required String failedMsg}) async {
    try {
      await CollectionService.join(collectionId, groupId, content);
      if (mounted) {
        Fluttertoast.showToast(msg: successMsg);
        Navigator.pop(context);
      }
    } catch (e) {
      _toastError(e, failedMsg);
    }
  }

  void _confirmDeleteEntry() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l10n.confirm),
        content: Text(_l10n.confirmDeleteEntry),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _doDeleteEntry();
            },
            child: Text(_l10n.delete,
                style: TextStyle(color: dialogContext.colors.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _doDeleteEntry() async {
    try {
      await CollectionService.deleteEntry(collectionId, groupId);
      if (mounted) {
        Fluttertoast.showToast(msg: _l10n.collectionDeleteSuccess);
        _fetchCollectionDetail();
      }
    } catch (e) {
      _toastError(e, _l10n.deleteFailed);
    }
  }

  /// 3003 = 已不在该群;这个错在接龙里很常见,单独给一句人话。
  void _toastError(Object e, String fallback) {
    final msg = e.toString();
    if (msg.contains('3003')) {
      Fluttertoast.showToast(msg: _l10n.collectionNotInGroup);
    } else {
      Fluttertoast.showToast(msg: '$fallback: $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final body = isLoading
        ? const Center(child: CircularProgressIndicator())
        : collection == null
            ? Center(
                child: Text(
                  _l10n.collectionLoadFailed,
                  style: AppText.base.copyWith(color: colors.textSecondary),
                ),
              )
            : _buildContent();

    if (widget.asDialog) {
      return PcDialogFrame(
        title: _l10n.collectionDetail,
        primary: (collection?.isJoinable ?? false)
            ? PcDialogAction(
                label: _l10n.submit, onPressed: _canSubmit ? _onSubmit : null)
            : null,
        secondary: (collection?.isJoinable ?? false)
            ? PcDialogAction(
                label: _l10n.cancel, onPressed: () => Navigator.pop(context))
            : null,
        child: Container(color: colors.primaryBackground, child: body),
      );
    }

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: AppBar(
        title: Text(_l10n.collectionDetail),
        actions: [
          if (collection?.isJoinable ?? false)
            AppBarTextAction(
              label: _l10n.submit,
              onPressed: _canSubmit ? _onSubmit : null,
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildContent() {
    final colors = context.colors;
    final entries = collection!.validEntries;
    // 未参与且接龙进行中时,清单末尾挂一行空的编辑位
    final showNewEntryRow = collection!.isJoinable && !hasJoined;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < entries.length; i++) ...[
                if (i > 0) const Divider(),
                _buildEntryRow(i + 1, entries[i]),
              ],
              if (showNewEntryRow) ...[
                if (entries.isNotEmpty) const Divider(),
                _buildEntryRow(entries.length + 1, null),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            collection!.title,
            style: AppText.xl.copyWith(
                fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          if (collection!.desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              collection!.desc,
              style: AppText.base.copyWith(color: colors.textSecondary),
            ),
          ],
          if (collection!.template.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_l10n.collectionTemplateLabel}${collection!.template}',
                style: AppText.xs.copyWith(color: colors.accent),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FutureBuilder<UserInfo?>(
            future: Imclient.getUserInfo(collection!.creatorId),
            builder: (context, snapshot) {
              final creatorInfo = snapshot.data;
              final creatorName = creatorInfo?.displayName ??
                  creatorInfo?.name ??
                  collection!.creatorId;
              return Row(
                children: [
                  Portrait(
                    creatorInfo?.portrait ?? '',
                    '',
                    width: 24,
                    height: 24,
                    borderRadius: 12,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$creatorName ${_l10n.collectionCreatorSuffix}',
                      style: AppText.xs.copyWith(color: colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${collection!.participantCount}${_l10n.collectionPeopleCount}',
                    style: AppText.xs.copyWith(color: colors.textTertiary),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 清单里的一行。[entry] 为 null 表示末尾那行「轮到你了」的空位。
  /// 自己那行在接龙进行中时是输入框,其余是纯文本。
  Widget _buildEntryRow(int displayIndex, CollectionEntry? entry) {
    final colors = context.colors;
    final isMine = entry == null || entry.userId == currentUserId;
    final editable = isMine && collection!.isJoinable;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: editable ? colors.accentSoft : Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: editable ? colors.accent : colors.hairlineSoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$displayIndex',
                style: AppText.xxs.copyWith(
                  color: editable ? colors.onAccent : colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: editable
                ? TextField(
                    controller: _editController,
                    autofocus: entry == null,
                    style: AppText.base.copyWith(color: colors.textPrimary),
                    cursorColor: colors.accent,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: collection!.template.isNotEmpty
                          ? collection!.template
                          : _l10n.collectionJoinHint,
                      hintStyle:
                          AppText.base.copyWith(color: colors.textTertiary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      entry!.content,
                      style: AppText.base.copyWith(color: colors.textPrimary),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
