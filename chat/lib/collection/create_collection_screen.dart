import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_dialog.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/widget/app_bar_actions.dart';
import 'package:chat/widget/form_card.dart';
import 'package:chat/widget/option_item.dart';
import 'collection_service.dart';

/// 发起接龙。移动端整页,桌面端弹窗,入口统一走 [show]。
class CreateCollectionScreen extends StatefulWidget {
  final Conversation conversation;
  final bool asDialog;

  const CreateCollectionScreen({
    super.key,
    required this.conversation,
    this.asDialog = false,
  });

  static Future<void> show(BuildContext context, Conversation conversation) {
    if (isDesktopShell) {
      return showPcDialog(
        context: context,
        width: 460,
        height: 560,
        builder: (_) =>
            CreateCollectionScreen(conversation: conversation, asDialog: true),
      );
    }
    return Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreateCollectionScreen(conversation: conversation)),
    );
  }

  @override
  State<CreateCollectionScreen> createState() => _CreateCollectionScreenState();
}

class _CreateCollectionScreenState extends State<CreateCollectionScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _templateController = TextEditingController();

  /// null / 0 表示无截止时间
  int? _expireAt;

  bool _isCreating = false;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _templateController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty && !_isCreating;

  Future<void> _createCollection() async {
    if (!_canSubmit) return;

    if (!CollectionService.isAvailable) {
      Fluttertoast.showToast(msg: _l10n.collectionServiceNotConfigured);
      return;
    }

    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final template = _templateController.text.trim();

    int expireType = 0;
    int expireAt = 0;
    if (_expireAt != null && _expireAt! > 0) {
      if (DateTime.fromMillisecondsSinceEpoch(_expireAt!)
          .isBefore(DateTime.now())) {
        Fluttertoast.showToast(msg: _l10n.expireTimeInvalid);
        return;
      }
      expireType = 1;
      expireAt = _expireAt!;
    }

    setState(() => _isCreating = true);

    try {
      await CollectionService.create(
        groupId: widget.conversation.target,
        title: title,
        desc: desc.isNotEmpty ? desc : null,
        template: template.isNotEmpty ? template : null,
        expireType: expireType,
        expireAt: expireAt,
      );

      if (mounted) {
        Fluttertoast.showToast(msg: _l10n.collectionCreateSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: '${_l10n.collectionCreateFailed}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _pickExpireTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expireAt != null
          ? DateTime.fromMillisecondsSinceEpoch(_expireAt!)
          : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _expireAt != null
          ? TimeOfDay.fromDateTime(
              DateTime.fromMillisecondsSinceEpoch(_expireAt!))
          : TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _expireAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute)
              .millisecondsSinceEpoch;
    });
  }

  String _formatExpireTime(int? timestamp) {
    if (timestamp == null || timestamp == 0) {
      return _l10n.collectionNoEndTime;
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;

    if (widget.asDialog) {
      return PcDialogFrame(
        title: l10n.createCollection,
        primary: PcDialogAction(
          label: l10n.done,
          onPressed: _canSubmit ? _createCollection : null,
          busy: _isCreating,
        ),
        secondary: PcDialogAction(
          label: l10n.cancel,
          onPressed: _isCreating ? null : () => Navigator.pop(context),
        ),
        child: _buildForm(),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.primaryBackground,
      appBar: AppBar(
        title: Text(l10n.createCollection),
        actions: [
          AppBarTextAction(
            label: l10n.done,
            onPressed: _canSubmit ? _createCollection : null,
            isLoading: _isCreating,
          ),
        ],
      ),
      body: _buildForm(),
    );
  }

  Widget _buildForm() {
    final l10n = _l10n;
    final colors = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormCard(
            children: [
              FormTextRow(
                controller: _titleController,
                hint: l10n.collectionTitleHint,
                onChanged: (_) => setState(() {}),
              ),
              FormTextRow(
                controller: _descController,
                hint: l10n.collectionDescHint,
                maxLines: 3,
                style: AppText.base,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 模板:决定群成员参与时输入框里的占位格式
          FormSectionLabel(l10n.collectionTemplate),
          FormCard(
            children: [
              FormTextRow(
                controller: _templateController,
                hint: l10n.collectionTemplateExample,
                style: AppText.base,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              l10n.collectionTemplateHint,
              style: AppText.xs.copyWith(color: colors.textTertiary),
            ),
          ),

          const SizedBox(height: 16),

          FormCard(
            padding: EdgeInsets.zero,
            children: [
              OptionItem(
                l10n.collectionEndTime,
                desc: _formatExpireTime(_expireAt),
                showBottomDivider: false,
                onTap: _pickExpireTime,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
