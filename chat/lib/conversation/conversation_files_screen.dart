import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/file_record.dart';
import 'package:chat/utilities.dart';

class ConversationFilesScreen extends StatefulWidget {
  final Conversation conversation;

  const ConversationFilesScreen(this.conversation, {super.key});

  @override
  State<ConversationFilesScreen> createState() => _ConversationFilesScreenState();
}

class _ConversationFilesScreenState extends State<ConversationFilesScreen> {
  List<FileRecord> _files = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _beforeMessageUid = 0;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  void _loadFiles() {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    Imclient.getConversationFiles(
      _beforeMessageUid,
      FileRecordOrder.TIME_DESC,
      20,
      (files) {
        if (mounted) {
          setState(() {
            _files.addAll(files);
            _isLoading = false;
            if (files.isNotEmpty) {
              _beforeMessageUid = files.last.messageUid;
            }
            if (files.length < 20) {
              _hasMore = false;
            }
          });
        }
      },
      (errorCode) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
      conversation: widget.conversation,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('会话文件'),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!_isLoading &&
              _hasMore &&
              scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            _loadFiles();
          }
          return false;
        },
        child: _files.isEmpty
            ? const Center(child: Text('没有文件'))
            : ListView.separated(
                itemCount: _files.length + (_hasMore ? 1 : 0),
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == _files.length) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var file = _files[index];
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file, size: 40),
                    title: Text(file.name ?? 'Unknown File'),
                    subtitle: Text(
                        '${Utilities.formatSize(file.size)}  ${Utilities.formatTime(file.timestamp)}'),
                    onTap: () {
                      // TODO: Open or download file
                    },
                  );
                },
              ),
      ),
    );
  }
}
