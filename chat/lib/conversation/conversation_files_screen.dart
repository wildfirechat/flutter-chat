import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/file_record.dart';
import 'package:chat/utilities.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';

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
  String? _keyword;

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

    final onSuccess = (List<FileRecord> files) {
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
    };

    final onError = (int errorCode) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    };

    if (_keyword != null && _keyword!.isNotEmpty) {
      Imclient.searchFiles(
        _keyword!,
        _beforeMessageUid,
        FileRecordOrder.TIME_DESC,
        20,
        onSuccess,
        onError,
        conversation: widget.conversation,
      );
    } else {
      Imclient.getConversationFiles(
        _beforeMessageUid,
        FileRecordOrder.TIME_DESC,
        20,
        onSuccess,
        onError,
        conversation: widget.conversation,
      );
    }
  }

  Future<void> _openFile(BuildContext context, FileRecord file) async {
    final url = file.url;
    if (url.isEmpty) {
      return;
    }
    Imclient.getAuthorizedMediaUrl(
      url,
      file.messageUid,
      MediaType.Media_Type_FILE.index,
      (authorizedUrl) {
        Utilities.openLink(context, authorizedUrl);
      },
      (errorCode) {
        Utilities.openLink(context, url);
      },
    );
  }

  Future<void> _deleteFile(FileRecord file) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteFileRecordConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    Imclient.deleteFileRecord(
      file.messageUid,
      () {
        if (mounted) {
          setState(() {
            _files.removeWhere((f) => f.messageUid == file.messageUid);
          });
          Fluttertoast.showToast(msg: l10n.fileRecordDeleted);
        }
      },
      (errorCode) {
        if (mounted) {
          Fluttertoast.showToast(msg: l10n.deleteFileRecordFailed);
        }
      },
    );
  }

  bool _canDelete(FileRecord file) {
    return file.userId == Imclient.currentUserId;
  }

  void _startSearch() {
    showSearch(
      context: context,
      delegate: _ConversationFileSearchDelegate(
        onSearch: (keyword) {
          setState(() {
            _keyword = keyword;
            _files.clear();
            _beforeMessageUid = 0;
            _hasMore = true;
          });
          _loadFiles();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      IconButton(
        icon: const Icon(Icons.search),
        onPressed: _startSearch,
      ),
    ];

    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: AppLocalizations.of(context)!.chatFiles,
              onBack: () => Navigator.of(context).maybePop(),
              actions: actions,
            )
          : AppBar(
              title: Text(AppLocalizations.of(context)!.chatFiles),
              actions: actions,
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
            ? Center(child: Text(AppLocalizations.of(context)!.noFiles))
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
                    title: Text(file.name ?? AppLocalizations.of(context)!.unknownFile, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${Utilities.formatSize(file.size)}  ${Utilities.formatTime(context, file.timestamp)}'),
                    trailing: _canDelete(file)
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteFile(file),
                          )
                        : null,
                    onTap: () => _openFile(context, file),
                  );
                },
              ),
      ),
    );
  }
}

class _ConversationFileSearchDelegate extends SearchDelegate<void> {
  final ValueChanged<String> onSearch;

  _ConversationFileSearchDelegate({required this.onSearch});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onSearch(query.trim());
    close(context, null);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Center(child: Text(AppLocalizations.of(context)!.searchPrompt));
  }
}
