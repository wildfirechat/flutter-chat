import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/l10n/app_localizations.dart';

import '../config.dart';
import 'poll_service.dart';

class CreatePollScreen extends StatefulWidget {
  final Conversation conversation;

  const CreatePollScreen({super.key, required this.conversation});

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
  int _visibility = 1; // 1=仅群内, 2=公开
  int _showResult = 0; // 0=投票前隐藏, 1=始终显示
  int? _endTime;

  bool _isCreating = false;

  static const int MIN_OPTIONS = 2;
  static const int MAX_OPTIONS = 10;

  bool get _isServiceAvailable => PollService.isAvailable;

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
    if (_optionControllers.length >= MAX_OPTIONS) {
      Fluttertoast.showToast(
        msg: _l10n.pollMaxOptionsLimit(MAX_OPTIONS),
      );
      return;
    }
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= MIN_OPTIONS) {
      Fluttertoast.showToast(
        msg: _l10n.pollMinOptionsRequired(MIN_OPTIONS),
      );
      return;
    }
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
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

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  Future<void> _pickEndTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        setState(() {
          _endTime = dateTime.millisecondsSinceEpoch;
        });
      }
    }
  }

  void _showPollTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10n.pollType),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              title: Text(_l10n.pollSingleChoice),
              value: 1,
              groupValue: _type,
              onChanged: (value) {
                Navigator.pop(context);
                setState(() {
                  _type = value!;
                  _maxSelect = 1;
                });
              },
            ),
            RadioListTile<int>(
              title: Text(_l10n.pollMultiChoice),
              value: 2,
              groupValue: _type,
              onChanged: (value) {
                Navigator.pop(context);
                setState(() {
                  _type = value!;
                  _maxSelect = 2;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMaxSelectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10n.pollMaxSelect),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            _optionControllers.length - 1,
            (index) => RadioListTile<int>(
              title: Text('${index + 2}${_l10n.pollOptions}'),
              value: index + 2,
              groupValue: _maxSelect,
              onChanged: (value) {
                Navigator.pop(context);
                setState(() => _maxSelect = value!);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createPoll),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _canSubmit ? _createPoll : null,
              // style: TextButton.styleFrom(
              //   foregroundColor: Colors.white,
              //   disabledForegroundColor: Colors.white.withOpacity(0.5),
              // ),
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                      ),
                    )
                  : Text(
                      l10n.publish,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题输入
            _buildSection(
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: l10n.pollTitleHint,
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (_) => setState(() {}),
              ),
            ),

            const SizedBox(height: 12),

            // 描述输入
            _buildSection(
              child: TextField(
                controller: _descController,
                decoration: InputDecoration(
                  hintText: l10n.pollDescHint,
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 16),
                maxLines: 3,
              ),
            ),

            const SizedBox(height: 16),

            // 选项列表
            _buildSection(
              child: Column(
                children: [
                  ..._optionControllers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controller = entry.value;
                    return _buildOptionItem(index, controller);
                  }).toList(),
                  // 添加选项按钮
                  if (_optionControllers.length < MAX_OPTIONS)
                    InkWell(
                      onTap: _addOption,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.pollAddOption,
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 设置项
            _buildSection(
              child: Column(
                children: [
                  // 投票类型
                  InkWell(
                    onTap: _showPollTypeDialog,
                    child: _buildSettingItem(
                      title: l10n.pollType,
                      value: _type == 1 ? l10n.pollSingleChoice : l10n.pollMultiChoice,
                    ),
                  ),

                  // 多选时显示最多选几项
                  if (_type == 2)
                    InkWell(
                      onTap: _showMaxSelectDialog,
                      child: _buildSettingItem(
                        title: l10n.pollMaxSelect,
                        value: '$_maxSelect${l10n.pollOptions}',
                      ),
                    ),

                  // 匿名投票
                  _buildSwitchItem(
                    title: l10n.pollAnonymousVote,
                    value: _anonymous == 1,
                    onChanged: (value) {
                      setState(() => _anonymous = value ? 1 : 0);
                    },
                  ),

                  // 显示结果
                  _buildSwitchItem(
                    title: l10n.pollShowResult,
                    value: _showResult == 1,
                    onChanged: (value) {
                      setState(() => _showResult = value ? 1 : 0);
                    },
                  ),

                  // 截止时间
                  InkWell(
                    onTap: _pickEndTime,
                    child: _buildSettingItem(
                      title: l10n.pollEndTime,
                      value: _endTime == null
                          ? l10n.pollNoEndTime
                          : _formatEndTime(_endTime!),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: child,
    );
  }

  Widget _buildOptionItem(int index, TextEditingController controller) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '${_l10n.pollOption} ${index + 1}',
              border: InputBorder.none,
            ),
            style: const TextStyle(fontSize: 16),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (_optionControllers.length > MIN_OPTIONS)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () => _removeOption(index),
          ),
      ],
    );
  }

  Widget _buildSettingItem({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _formatEndTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
