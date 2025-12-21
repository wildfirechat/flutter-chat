import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/file_record.dart';
import 'package:chat/utilities.dart';
import 'package:chat/conversation/pick_conversation_screen.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/widget/option_item.dart';

class FileRecordsScreen extends StatelessWidget {
  const FileRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件记录'),
      ),
      body: Column(
        children: [
          OptionItem(
            '所有文件',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FileListScreen(
                    title: '所有文件',
                    child: FileListWidget(type: FileListType.all),
                  ),
                ),
              );
            },
          ),
          OptionItem(
            '我的文件',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FileListScreen(
                    title: '我的文件',
                    child: FileListWidget(type: FileListType.my),
                  ),
                ),
              );
            },
          ),
          OptionItem(
            '会话文件',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PickConversationScreen(
                    onConversationSelected: (context, conversation) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FileListScreen(
                            title: '会话文件',
                            child: FileListWidget(
                              type: FileListType.conversation,
                              conversation: conversation,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          OptionItem(
            '用户文件',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PickUserScreen(
                    (context, users) {
                      if (users.isNotEmpty) {
                        var userId = users[0];
                        var conversation = Conversation(conversationType: ConversationType.Single, target: userId, line: 0);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FileListScreen(
                              title: '用户文件',
                              child: FileListWidget(
                                type: FileListType.user,
                                conversation: conversation,
                                userId: userId,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    maxSelected: 1,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class FileListScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const FileListScreen({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: child,
    );
  }
}

enum FileListType { all, my, conversation, user }

class FileListWidget extends StatefulWidget {
  final FileListType type;
  final Conversation? conversation;
  final String? userId;

  const FileListWidget({
    super.key,
    required this.type,
    this.conversation,
    this.userId,
  });

  @override
  State<FileListWidget> createState() => _FileListWidgetState();
}

class _FileListWidgetState extends State<FileListWidget> with AutomaticKeepAliveClientMixin {
  List<FileRecord> _files = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _beforeMessageUid = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void didUpdateWidget(FileListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversation != oldWidget.conversation || widget.userId != oldWidget.userId) {
      _refresh();
    }
  }

  void _refresh() {
    setState(() {
      _files.clear();
      _hasMore = true;
      _beforeMessageUid = 0;
      _isLoading = false;
    });
    _loadFiles();
  }

  void _loadFiles() {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    void onSuccess(List<FileRecord> files) {
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
    }

    void onError(int errorCode) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    if (widget.type == FileListType.my) {
      Imclient.getMyFiles(_beforeMessageUid, FileRecordOrder.TIME_DESC, 20, onSuccess, onError);
    } else {
      Imclient.getConversationFiles(
        _beforeMessageUid,
        FileRecordOrder.TIME_DESC,
        20,
        onSuccess,
        onError,
        conversation: widget.conversation,
        fromUser: widget.userId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_files.isEmpty && !_isLoading) {
      return const Center(child: Text('没有文件'));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!_isLoading &&
            _hasMore &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadFiles();
        }
        return false;
      },
      child: ListView.separated(
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
    );
  }
}


