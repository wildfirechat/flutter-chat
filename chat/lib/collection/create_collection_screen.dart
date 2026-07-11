import 'package:flutter/material.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/l10n/app_localizations.dart';


import 'collection_service.dart';
import 'package:chat/theme/app_typography.dart';

class CreateCollectionScreen extends StatefulWidget {
  final Conversation conversation;

  const CreateCollectionScreen({super.key, required this.conversation});

  @override
  State<CreateCollectionScreen> createState() => _CreateCollectionScreenState();
}

class _CreateCollectionScreenState extends State<CreateCollectionScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _templateController = TextEditingController();

  int? _expireAt; // 0或null表示无截止时间

  bool _isCreating = false;

  bool get _isServiceAvailable => CollectionService.isAvailable;

  @override
  void initState() {
    super.initState();
    // 默认无截止时间
    _expireAt = null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _templateController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _titleController.text.trim().isNotEmpty && !_isCreating;
  }

  Future<void> _createCollection() async {
    if (!_canSubmit) return;

    if (!_isServiceAvailable) {
      Fluttertoast.showToast(msg: _l10n.collectionServiceNotConfigured);
      return;
    }

    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final template = _templateController.text.trim();

    // 计算过期时间和类型
    int expireType = 0;
    int expireAt = 0;
    if (_expireAt != null && _expireAt! > 0) {
      if (DateTime.fromMillisecondsSinceEpoch(_expireAt!).isBefore(DateTime.now())) {
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

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

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

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _expireAt != null
            ? TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(_expireAt!))
            : TimeOfDay.now(),
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
          _expireAt = dateTime.millisecondsSinceEpoch;
        });
      }
    }
  }

  String _formatExpireTime(int? timestamp) {
    if (timestamp == null || timestamp == 0) {
      return _l10n.collectionNoEndTime;
    }
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createCollection),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _canSubmit ? _createCollection : null,
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
                      l10n.done,
                      style: AppText.lg.copyWith(fontWeight: FontWeight.w600),
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
            // 标题输入（与投票页面样式一致：白色背景，无边框）
            _buildCardSection(
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: l10n.collectionTitleHint,
                  border: InputBorder.none,
                ),
                style: AppText.lg,
                onChanged: (_) => setState(() {}),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 描述输入
            _buildCardSection(
              child: TextField(
                controller: _descController,
                decoration: InputDecoration(
                  hintText: l10n.collectionDescHint,
                  border: InputBorder.none,
                ),
                style: AppText.lg,
                maxLines: 3,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 模板输入（带标题和说明）
            _buildCardSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.collectionTemplate,
                    style: AppText.lg.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.collectionTemplateHint,
                    style: AppText.xs.copyWith(color: Colors.grey[600]),
                  ),
                  TextField(
                    controller: _templateController,
                    decoration: InputDecoration(
                      hintText: l10n.collectionTemplateExample,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: AppText.lg,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 截止时间设置（与投票页面样式一致）
            _buildCardSection(
              child: InkWell(
                onTap: _pickExpireTime,
                child: _buildSettingItem(
                  title: l10n.collectionEndTime,
                  value: _formatExpireTime(_expireAt),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 卡片样式容器（与投票页面 _buildSection 一致）
  Widget _buildCardSection({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: child,
    );
  }

  Widget _buildSettingItem({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppText.lg,
          ),
          Row(
            children: [
              Text(
                value,
                style: AppText.base.copyWith(color: Colors.grey[600]),
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
}
