import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moment/client/momentclient.dart';

import 'moment_config.dart';
import 'moment_media_picker.dart';
import 'moment_upload.dart';
import 'visible_scope_page.dart';

/// 发布朋友圈页。
class PublishFeedPage extends StatefulWidget {
  /// 已选媒体（发布页内可继续添加/删除）。
  final List<MomentPickedMedia> initialMedias;

  const PublishFeedPage({super.key, this.initialMedias = const []});

  @override
  State<PublishFeedPage> createState() => _PublishFeedPageState();
}

class _PublishFeedPageState extends State<PublishFeedPage> {
  final TextEditingController _textController = TextEditingController();

  late final List<MomentPickedMedia> _medias = [...widget.initialMedias];

  /// 可见范围：0 公开 / 1 私密 / 2 部分可见 / 3 不给谁看。
  int _visibleScope = 0;
  List<String> _scopeUsers = [];
  List<String> _mentionUsers = [];

  bool _publishing = false;
  String _publishProgress = '';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _canPublish =>
      !_publishing &&
      (_textController.text.trim().isNotEmpty || _medias.isNotEmpty);

  Future<void> _addMedia() async {
    final remain = 9 - _medias.length;
    if (remain <= 0) return;
    final picked = await MomentKit.mediaPicker(context, maxCount: remain);
    if (picked.isEmpty || !mounted) return;
    setState(() => _medias.addAll(picked));
  }

  Future<void> _pickMentionUsers() async {
    final picker = MomentKit.contactPicker;
    if (picker == null) return;
    final selected = await picker(context, _mentionUsers);
    if (!mounted) return;
    setState(() => _mentionUsers = selected);
  }

  Future<void> _openVisibleScope() async {
    final result = await Navigator.of(context).push<VisibleScopeResult>(
      MaterialPageRoute(
        builder: (_) => VisibleScopePage(
          mode: _visibleScope,
          users: _scopeUsers,
          onPickUsers: (mode) async {
            final picker = MomentKit.contactPicker;
            if (picker == null) return _scopeUsers;
            return picker(context, _scopeUsers);
          },
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _visibleScope = result.mode;
        _scopeUsers = result.users;
      });
    }
  }

  String get _scopeDesc {
    switch (_visibleScope) {
      case 1:
        return '私密';
      case 2:
        return _scopeUsers.isEmpty ? '部分可见' : '部分可见(${_scopeUsers.length}人)';
      case 3:
        return _scopeUsers.isEmpty ? '不给谁看' : '不给谁看(${_scopeUsers.length}人)';
      default:
        return '公开';
    }
  }

  Future<void> _publish() async {
    if (!_canPublish) return;
    setState(() {
      _publishing = true;
      _publishProgress = '上传中...';
    });
    try {
      final entries = <FeedEntry>[];
      for (var i = 0; i < _medias.length; i++) {
        if (!mounted) return;
        setState(() => _publishProgress = '上传中(${i + 1}/${_medias.length})');
        final media = _medias[i];
        entries.add(media.isVideo
            ? await MomentUploader.uploadVideo(media.path)
            : await MomentUploader.uploadImage(media.path));
      }

      if (!mounted) return;
      setState(() => _publishProgress = '发表中...');

      final text = _textController.text.trim();
      final WFMContentType type;
      if (_medias.isEmpty) {
        type = WFMContentType.WFMContent_Text_Type;
      } else if (_medias.length == 1 && _medias.first.isVideo) {
        type = WFMContentType.WFMContent_Video_Type;
      } else {
        type = WFMContentType.WFMContent_Image_Type;
      }

      await MomentClient.postFeed(
        type,
        text: text.isEmpty ? null : text,
        medias: entries.isEmpty ? null : entries,
        mentionedUsers: _mentionUsers.isEmpty ? null : _mentionUsers,
        toUsers: _visibleScope == 2 ? _scopeUsers : null,
        excludeUsers: _visibleScope == 3 ? _scopeUsers : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _publishProgress = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发表失败($e)'), duration: const Duration(seconds: 2)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_medias.isEmpty ? '发表文字' : '发表'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _canPublish ? _publish : null,
              child: const Text('发表'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(12),
            children: [
              TextField(
                controller: _textController,
                maxLines: null,
                minLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: '这一刻的想法...',
                  border: InputBorder.none,
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_medias.isNotEmpty) _buildMediaGrid(),
              const SizedBox(height: 16),
              const Divider(height: 0.5),
              if (MomentKit.contactPicker != null) ...[
                _buildOptionRow(
                  '提醒谁看',
                  _mentionUsers.isEmpty
                      ? ''
                      : '${_mentionUsers.length} 人',
                  _pickMentionUsers,
                ),
                const Divider(height: 0.5),
              ],
              _buildOptionRow('谁可以看', _scopeDesc, _openVisibleScope),
              const Divider(height: 0.5),
            ],
          ),
          if (_publishing)
            Container(
              color: Colors.black26,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(_publishProgress),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [
        for (var i = 0; i < _medias.length; i++)
          _buildMediaCell(_medias[i], i),
        if (_medias.length < 9)
          GestureDetector(
            onTap: _addMedia,
            child: Container(
              color: const Color(0xFFF3F3F5),
              child: const Icon(Icons.add, size: 40, color: Colors.black26),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaCell(MomentPickedMedia media, int index) {
    return GestureDetector(
      onLongPress: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            content: const Text('删除这张照片吗？'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消')),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _medias.removeAt(index));
                },
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (media.isVideo)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Icon(Icons.play_circle_fill,
                    color: Colors.white70, size: 36),
              ),
            )
          else
            Image.file(File(media.path), fit: BoxFit.cover),
        ],
      ),
    );
  }

  Widget _buildOptionRow(String title, String desc, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 15)),
            const Spacer(),
            if (desc.isNotEmpty)
              Text(desc,
                  style: const TextStyle(fontSize: 14, color: Colors.black38)),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
