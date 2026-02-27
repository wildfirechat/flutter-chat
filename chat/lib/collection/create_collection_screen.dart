import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/model/conversation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../config.dart';
import 'collection_service.dart';

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

  int _expireType = 0; // 0=无限期，1=有限期
  DateTime? _expireDate;
  TimeOfDay? _expireTime;

  bool _isCreating = false;

  bool get _isServiceAvailable => CollectionService.isAvailable;

  @override
  void initState() {
    super.initState();
    // 默认设置为24小时后
    final now = DateTime.now();
    _expireDate = now.add(const Duration(days: 1));
    _expireTime = TimeOfDay.fromDateTime(now.add(const Duration(days: 1)));
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

    // 计算过期时间
    int expireAt = 0;
    if (_expireType == 1 && _expireDate != null && _expireTime != null) {
      final expireDateTime = DateTime(
        _expireDate!.year,
        _expireDate!.month,
        _expireDate!.day,
        _expireTime!.hour,
        _expireTime!.minute,
      );
      
      if (expireDateTime.isBefore(DateTime.now())) {
        Fluttertoast.showToast(msg: _l10n.expireTimeInvalid);
        return;
      }
      expireAt = expireDateTime.millisecondsSinceEpoch;
    }

    setState(() => _isCreating = true);

    try {
      await CollectionService.create(
        groupId: widget.conversation.target,
        title: title,
        desc: desc.isNotEmpty ? desc : null,
        template: template.isNotEmpty ? template : null,
        expireType: _expireType,
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

  Future<void> _pickExpireDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expireDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() => _expireDate = picked);
    }
  }

  Future<void> _pickExpireTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _expireTime ?? TimeOfDay.now(),
    );
    
    if (picked != null) {
      setState(() => _expireTime = picked);
    }
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
              title: l10n.collectionTitle,
              required: true,
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: l10n.collectionTitleHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, 
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (_) => setState(() {}),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 描述输入
            _buildSection(
              title: l10n.collectionDesc,
              child: TextField(
                controller: _descController,
                decoration: InputDecoration(
                  hintText: l10n.collectionDescHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, 
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                maxLines: 3,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 模板输入
            _buildSection(
              title: l10n.collectionTemplate,
              subtitle: l10n.collectionTemplateHint,
              child: TextField(
                controller: _templateController,
                decoration: InputDecoration(
                  hintText: l10n.collectionTemplateExample,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, 
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 过期设置
            _buildSection(
              title: l10n.expireSetting,
              child: Column(
                children: [
                  // 无限期选项
                  RadioListTile<int>(
                    title: Text(l10n.noExpire),
                    value: 0,
                    groupValue: _expireType,
                    onChanged: (value) {
                      setState(() => _expireType = value!);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  // 设置过期时间选项
                  RadioListTile<int>(
                    title: Text(l10n.setExpire),
                    value: 1,
                    groupValue: _expireType,
                    onChanged: (value) {
                      setState(() => _expireType = value!);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  // 过期时间选择器
                  if (_expireType == 1)
                    Container(
                      margin: const EdgeInsets.only(left: 16, top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          // 日期选择
                          InkWell(
                            onTap: _pickExpireDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12, 
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n.expireDate,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  Text(
                                    _expireDate != null
                                        ? '${_expireDate!.year}-${_expireDate!.month.toString().padLeft(2, '0')}-${_expireDate!.day.toString().padLeft(2, '0')}'
                                        : l10n.pleaseSelect,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: _expireDate != null 
                                          ? Colors.black 
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // 时间选择
                          InkWell(
                            onTap: _pickExpireTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12, 
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n.expireTime,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  Text(
                                    _expireTime != null
                                        ? '${_expireTime!.hour.toString().padLeft(2, '0')}:${_expireTime!.minute.toString().padLeft(2, '0')}'
                                        : l10n.pleaseSelect,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: _expireTime != null 
                                          ? Colors.black 
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildSection({
    required String title,
    String? subtitle,
    bool required = false,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
