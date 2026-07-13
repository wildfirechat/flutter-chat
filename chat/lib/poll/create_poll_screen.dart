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
import 'package:chat/widget/option_switch_item.dart';
import 'poll_service.dart';

/// 发起投票。
///
/// 移动端是整页表单(AppBar 右上角「发布」),桌面端是弹窗(操作栏「取消 / 发布」)——
/// 表单与提交逻辑同一份,只有外壳按端切换,入口统一走 [show]。
class CreatePollScreen extends StatefulWidget {
  final Conversation conversation;

  /// 桌面端以 [PcDialogFrame] 承载,不要自己带 Scaffold/AppBar。
  final bool asDialog;

  const CreatePollScreen({
    super.key,
    required this.conversation,
    this.asDialog = false,
  });

  static Future<void> show(BuildContext context, Conversation conversation) {
    if (isDesktopShell) {
      return showPcDialog(
        context: context,
        width: 460,
        height: 620,
        builder: (_) => CreatePollScreen(conversation: conversation, asDialog: true),
      );
    }
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreatePollScreen(conversation: conversation)),
    );
  }

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];

  int _type = 1; // 1=单选, 2=多选
  int _maxSelect = 1;
  int _anonymous = 0;
  final int _visibility = 1; // 1=仅群内, 2=公开
  int _showResult = 0; // 0=投票前隐藏, 1=始终显示
  int? _endTime;

  bool _isCreating = false;

  static const int minOptions = 2;
  static const int maxOptions = 10;

  bool get _isServiceAvailable => PollService.isAvailable;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    // 默认两个空选项
    _addOption();
    _addOption();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= maxOptions) {
      Fluttertoast.showToast(msg: _l10n.pollMaxOptionsLimit(maxOptions));
      return;
    }
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= minOptions) {
      Fluttertoast.showToast(msg: _l10n.pollMinOptionsRequired(minOptions));
      return;
    }
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
      // 选项减少后,「最多选几项」可能已越界
      if (_maxSelect > _optionControllers.length) {
        _maxSelect = _optionControllers.length;
      }
    });
  }

  bool get _canSubmit {
    if (_titleController.text.trim().isEmpty) return false;
    if (_optionControllers.any((c) => c.text.trim().isEmpty)) return false;
    return !_isCreating;
  }

  Future<void> _createPoll() async {
    if (!_canSubmit) return;

    if (!_isServiceAvailable) {
      Fluttertoast.showToast(msg: _l10n.pollServiceNotConfigured);
      return;
    }

    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final options = _optionControllers.map((c) => c.text.trim()).toList();

    setState(() => _isCreating = true);

    try {
      await PollService.create(
        groupId: widget.conversation.target,
        title: title,
        desc: desc.isNotEmpty ? desc : null,
        options: options,
        visibility: _visibility,
        type: _type,
        maxSelect: _type == 2 ? _maxSelect : 1,
        anonymous: _anonymous,
        endTime: _endTime ?? 0,
        showResult: _showResult,
      );

      if (mounted) {
        Fluttertoast.showToast(msg: _l10n.pollCreateSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: '${_l10n.pollCreateFailed}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _pickEndTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _endTime != null ? DateTime.fromMillisecondsSinceEpoch(_endTime!) : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _endTime != null
          ? TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(_endTime!))
          : TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute).millisecondsSinceEpoch;
    });
  }

  Future<void> _pickPollType() async {
    final type = await showFormOptionPicker<int>(
      context: context,
      title: _l10n.pollType,
      current: _type,
      options: [
        (value: 1, label: _l10n.pollSingleChoice),
        (value: 2, label: _l10n.pollMultiChoice),
      ],
    );
    if (type == null) return;
    setState(() {
      _type = type;
      // 单选恒为 1;切到多选时给一个合法的默认上限
      _maxSelect = type == 1 ? 1 : _maxSelect.clamp(2, _optionControllers.length);
    });
  }

  Future<void> _pickMaxSelect() async {
    // 最多可选的上限是选项总数,下限 2(否则等同单选)
    final choices = [
      for (int n = 2; n <= _optionControllers.length; n++) (value: n, label: '$n${_l10n.pollOptions}'),
    ];
    if (choices.isEmpty) return;

    final value = await showFormOptionPicker<int>(
      context: context,
      title: _l10n.pollMaxSelect,
      current: _maxSelect,
      options: choices,
    );
    if (value == null) return;
    setState(() => _maxSelect = value);
  }

  String _formatEndTime(int timestamp) {
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
        title: l10n.createPoll,
        primary: PcDialogAction(
          label: l10n.publish,
          onPressed: _canSubmit ? _createPoll : null,
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
        title: Text(l10n.createPoll),
        actions: [
          AppBarTextAction(
            label: l10n.publish,
            onPressed: _canSubmit ? _createPoll : null,
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
          // 标题 + 描述
          FormCard(
            children: [
              FormTextRow(
                controller: _titleController,
                hint: l10n.pollTitleHint,
                onChanged: (_) => setState(() {}),
              ),
              FormTextRow(
                controller: _descController,
                hint: l10n.pollDescHint,
                maxLines: 3,
                style: AppText.base,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 选项
          FormSectionLabel(l10n.pollOptionsTitle),
          FormCard(
            children: [
              for (int i = 0; i < _optionControllers.length; i++) _buildOptionRow(i),
              if (_optionControllers.length < maxOptions)
                InkWell(
                  onTap: _addOption,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 20, color: colors.accent),
                        const SizedBox(width: 8),
                        Text(l10n.pollAddOption, style: AppText.base.copyWith(color: colors.accent)),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // 设置。行间线由 FormCard 统一画,故各行都关掉自己的底线。
          FormCard(
            padding: EdgeInsets.zero,
            children: [
              OptionItem(
                l10n.pollType,
                desc: _type == 1 ? l10n.pollSingleChoice : l10n.pollMultiChoice,
                showBottomDivider: false,
                onTap: _pickPollType,
              ),
              if (_type == 2)
                OptionItem(
                  l10n.pollMaxSelect,
                  desc: '$_maxSelect${l10n.pollOptions}',
                  showBottomDivider: false,
                  onTap: _pickMaxSelect,
                ),
              OptionSwitchItem(
                l10n.pollAnonymousVote,
                _anonymous == 1,
                (v) => setState(() => _anonymous = v ? 1 : 0),
                showBottomDivider: false,
              ),
              OptionSwitchItem(
                l10n.pollShowResult,
                _showResult == 1,
                (v) => setState(() => _showResult = v ? 1 : 0),
                showBottomDivider: false,
              ),
              OptionItem(
                l10n.pollEndTime,
                desc: _endTime == null ? l10n.pollNoEndTime : _formatEndTime(_endTime!),
                showBottomDivider: false,
                onTap: _pickEndTime,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(int index) {
    return Row(
      children: [
        Expanded(
          child: FormTextRow(
            controller: _optionControllers[index],
            hint: '${_l10n.pollOption} ${index + 1}',
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (_optionControllers.length > minOptions)
          IconButton(
            icon: Icon(Icons.remove_circle_outline, size: 20, color: context.colors.textTertiary),
            splashRadius: 18,
            tooltip: _l10n.delete,
            onPressed: () => _removeOption(index),
          ),
      ],
    );
  }
}
