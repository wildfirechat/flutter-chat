import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/collection_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/l10n/app_localizations.dart';

import '../widget/portrait.dart';
import 'collection_model.dart';
import 'collection_service.dart';
import '../config.dart';

class CollectionDetailScreen extends StatefulWidget {
  final Message message;

  const CollectionDetailScreen({super.key, required this.message});

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
  bool isCreator = false;
  int myEntryIndex = -1;
  String? myEntryContent;

  final TextEditingController _editController = TextEditingController();
  String? _originalContent;
  final Map<int, TextEditingController> _entryControllers = {};

  bool get _isServiceAvailable => CollectionService.isAvailable;

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
    for (var controller in _entryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchCollectionDetail() async {
    if (!_isServiceAvailable) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final result = await CollectionService.getCollection(collectionId, groupId);
      setState(() {
        collection = result;
        isLoading = false;
        _updateJoinStatus();
      });
    } catch (e) {
      setState(() => isLoading = false);
      Fluttertoast.showToast(msg: '${_l10n.collectionLoadFailed}: $e');
    }
  }

  void _updateJoinStatus() {
    if (collection == null) return;

    hasJoined = false;
    myEntryIndex = -1;
    myEntryContent = null;

    final entries = collection!.validEntries;
    for (int i = 0; i < entries.length; i++) {
      if (currentUserId == entries[i].userId) {
        hasJoined = true;
        myEntryIndex = i;
        myEntryContent = entries[i].content;
        break;
      }
    }

    isCreator = currentUserId == collection!.creatorId;

    // 初始化编辑框内容
    if (hasJoined && myEntryContent != null) {
      _editController.text = myEntryContent!;
      _originalContent = myEntryContent;
    } else {
      _editController.clear();
      _originalContent = '';
    }
  }

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  bool get _canSubmit {
    if (collection == null || !(collection!.isJoinable)) return false;

    final currentContent = _editController.text.trim();
    
    if (hasJoined) {
      if (currentContent.isEmpty) {
        return myEntryContent?.isNotEmpty ?? false;
      }
      return currentContent != _originalContent;
    } else {
      return currentContent.isNotEmpty;
    }
  }

  Future<void> _onSubmit() async {
    if (!_isServiceAvailable) {
      Fluttertoast.showToast(msg: _l10n.collectionServiceNotConfigured);
      return;
    }

    final content = _editController.text.trim();

    if (hasJoined) {
      if (content.isEmpty) {
        _confirmDeleteEntry();
      } else {
        await _updateEntry(content);
      }
    } else {
      if (content.isEmpty) {
        Fluttertoast.showToast(msg: _l10n.collectionJoinHint);
        return;
      }
      await _joinCollection(content);
    }
  }

  Future<void> _joinCollection(String content) async {
    try {
      await CollectionService.join(collectionId, groupId, content);
      if (mounted) {
        Fluttertoast.showToast(msg: _l10n.collectionJoinSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('3003')) {
        Fluttertoast.showToast(msg: _l10n.collectionNotInGroup);
      } else {
        Fluttertoast.showToast(msg: '${_l10n.collectionJoinFailed}: $errorMsg');
      }
    }
  }

  Future<void> _updateEntry(String content) async {
    try {
      await CollectionService.join(collectionId, groupId, content);
      if (mounted) {
        Fluttertoast.showToast(msg: _l10n.collectionUpdateSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('3003')) {
        Fluttertoast.showToast(msg: _l10n.collectionNotInGroup);
      } else {
        Fluttertoast.showToast(msg: '${_l10n.collectionUpdateFailed}: $errorMsg');
      }
    }
  }

  void _confirmDeleteEntry() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10n.confirm),
        content: Text(_l10n.confirmDeleteEntry),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _doDeleteEntry();
            },
            child: Text(_l10n.delete, style: const TextStyle(color: Colors.red)),
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
      final errorMsg = e.toString();
      if (errorMsg.contains('3003')) {
        Fluttertoast.showToast(msg: _l10n.collectionNotInGroup);
      } else {
        Fluttertoast.showToast(msg: '${_l10n.deleteFailed}: $errorMsg');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(l10n.collectionDetail),
        actions: [
          if (collection?.isJoinable ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _canSubmit ? _onSubmit : null,
                // style: TextButton.styleFrom(
                //   foregroundColor: Colors.white,
                //   disabledForegroundColor: Colors.white.withOpacity(0.5),
                // ),
                child: Text(
                  l10n.submit,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : collection == null
              ? Center(child: Text(l10n.collectionLoadFailed))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              // 头部信息
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              // 参与列表
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entries = collection!.validEntries;
                    if (index < entries.length) {
                      return _buildEntryItem(index, entries[index]);
                    }
                    // 编辑行（未参与且接龙进行中）
                    if (index == entries.length && collection!.isJoinable && !hasJoined) {
                      return _buildEditRow(entries.length + 1);
                    }
                    return null;
                  },
                  childCount: _getItemCount(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _getItemCount() {
    if (collection == null) return 0;
    int count = collection!.validEntries.length;
    // 未参与且接龙进行中时，添加编辑行
    if (collection!.isJoinable && !hasJoined) {
      count += 1;
    }
    return count;
  }

  Widget _buildHeader() {
    return FutureBuilder<UserInfo?>(
      future: Imclient.getUserInfo(collection!.creatorId),
      builder: (context, snapshot) {
        final creatorInfo = snapshot.data;
        final creatorName = creatorInfo?.displayName ?? 
                           creatorInfo?.name ?? 
                           collection!.creatorId;

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 创建者信息
              Row(
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
                      '$creatorName ${_l10n.collectionCreatorSuffix} · ${collection!.participantCount}${_l10n.collectionPeopleCount}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF576b95),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 标题
              Text(
                collection!.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              
              // 描述
              if (collection!.desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  collection!.desc,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
              
              // 模板
              if (collection!.template.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_l10n.collectionTemplateLabel}${collection!.template}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF576b95),
                  ),
                ),
              ],
              
              // 分隔区域
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEntryItem(int index, CollectionEntry entry) {
    final isMyEntry = entry.userId == currentUserId;
    final displayIndex = index + 1;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 序号圆形
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF576b95),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                '$displayIndex',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF576b95),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // 内容
          Expanded(
            child: isMyEntry && collection!.isJoinable
                ? _buildMyEditField()
                : Text(
                    entry.content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF333333),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyEditField() {
    return TextField(
      controller: _editController,
      decoration: InputDecoration(
        hintText: collection!.template.isNotEmpty 
            ? collection!.template 
            : _l10n.collectionJoinHint,
        hintStyle: const TextStyle(
          fontSize: 15,
          color: Color(0xFF999999),
        ),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF333333),
      ),
      maxLines: 3,
      minLines: 1,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildEditRow(int index) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 序号圆形
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF576b95),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF576b95),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // 编辑框
          Expanded(
            child: TextField(
              controller: _editController,
              decoration: InputDecoration(
                hintText: collection!.template.isNotEmpty 
                    ? collection!.template 
                    : _l10n.collectionJoinHint,
                hintStyle: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF999999),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF333333),
              ),
              maxLines: 3,
              minLines: 1,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}
