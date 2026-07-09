import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/file_record.dart';
import 'package:chat/utilities.dart';
import 'package:chat/conversation/pick_conversation_screen.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/app_navigator.dart';

class FileRecordsScreen extends StatelessWidget {
  const FileRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(title: AppLocalizations.of(context)!.fileRecords)
          : AppBar(
              title: Text(AppLocalizations.of(context)!.fileRecords),
            ),
      body: Column(
        children: [
          OptionItem(
            AppLocalizations.of(context)!.allFiles,
            onTap: () {
              pushPage(
                context,
                FileListScreen(
                  title: AppLocalizations.of(context)!.allFiles,
                  onBack: () => Navigator.of(context).maybePop(),
                  child: const FileListWidget(type: FileListType.all),
                ),
              );
            },
          ),
          OptionItem(
            AppLocalizations.of(context)!.myFiles,
            onTap: () {
              pushPage(
                context,
                FileListScreen(
                  title: AppLocalizations.of(context)!.myFiles,
                  onBack: () => Navigator.of(context).maybePop(),
                  child: const FileListWidget(type: FileListType.my),
                ),
              );
            },
          ),
          OptionItem(
            AppLocalizations.of(context)!.chatFiles,
            onTap: () {
              pushPage(
                context,
                PickConversationScreen(
                  onBack: () => Navigator.of(context).maybePop(),
                  onConversationSelected: (context, conversation) {
                    final route = isDesktopShell
                        ? PageRouteBuilder(
                            settings: RouteSettings(
                              name: 'file-list/conversation',
                              arguments: {
                                'type': FileListType.conversation,
                                'conversation': conversation,
                              },
                            ),
                            pageBuilder: (_, __, ___) => FileListScreen(
                              title: AppLocalizations.of(context)!.chatFiles,
                              onBack: () => Navigator.of(context).maybePop(),
                              child: FileListWidget(
                                type: FileListType.conversation,
                                conversation: conversation,
                              ),
                            ),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          )
                        : MaterialPageRoute(
                            settings: RouteSettings(
                              name: 'file-list/conversation',
                              arguments: {
                                'type': FileListType.conversation,
                                'conversation': conversation,
                              },
                            ),
                            builder: (context) => FileListScreen(
                              title: AppLocalizations.of(context)!.chatFiles,
                              child: FileListWidget(
                                type: FileListType.conversation,
                                conversation: conversation,
                              ),
                            ),
                          );
                    Navigator.pushReplacement(context, route);
                  },
                ),
              );
            },
          ),
          OptionItem(
            AppLocalizations.of(context)!.userFiles,
            onTap: () {
              pushPage(
                context,
                PickUserScreen(
                  (context, users) {
                    if (users.isNotEmpty) {
                      var userId = users[0];
                      var conversation = Conversation(conversationType: ConversationType.Single, target: userId, line: 0);
                      final route = isDesktopShell
                          ? PageRouteBuilder(
                              settings: RouteSettings(
                                name: 'file-list/user',
                                arguments: {
                                  'type': FileListType.user,
                                  'conversation': conversation,
                                  'userId': userId,
                                },
                              ),
                              pageBuilder: (_, __, ___) => FileListScreen(
                                title: AppLocalizations.of(context)!.userFiles,
                                onBack: () => Navigator.of(context).maybePop(),
                                child: FileListWidget(
                                  type: FileListType.user,
                                  conversation: conversation,
                                  userId: userId,
                                ),
                              ),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            )
                          : MaterialPageRoute(
                              settings: RouteSettings(
                                name: 'file-list/user',
                                arguments: {
                                  'type': FileListType.user,
                                  'conversation': conversation,
                                  'userId': userId,
                                },
                              ),
                              builder: (context) => FileListScreen(
                                title: AppLocalizations.of(context)!.userFiles,
                                child: FileListWidget(
                                  type: FileListType.user,
                                  conversation: conversation,
                                  userId: userId,
                                ),
                              ),
                            );
                      Navigator.pushReplacement(context, route);
                    }
                  },
                  onBack: () => Navigator.of(context).maybePop(),
                  maxSelected: 1,
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
  final bool showSearchAction;
  final VoidCallback? onBack;

  const FileListScreen({
    super.key,
    required this.title,
    required this.child,
    this.showSearchAction = true,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final actions = showSearchAction
        ? [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: _FileSearchDelegate(),
                );
              },
            ),
          ]
        : null;

    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: title,
              onBack: onBack,
              actions: actions,
            )
          : AppBar(
              title: Text(title),
              actions: actions,
            ),
      body: child,
    );
  }
}

class _FileSearchDelegate extends SearchDelegate<FileRecord?> {
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
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchBody(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchBody(context);
  }

  Widget _buildSearchBody(BuildContext context) {
    if (query.trim().isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.searchPrompt));
    }
    FileListType? type;
    Conversation? conversation;
    String? userId;
    Navigator.of(context).popUntil((route) {
      if (route.settings.name != null && route.settings.name!.startsWith('file-list/')) {
        final args = route.settings.arguments as Map?;
        if (args != null) {
          type = args['type'] as FileListType?;
          conversation = args['conversation'] as Conversation?;
          userId = args['userId'] as String?;
        }
        return true;
      }
      return route.isFirst;
    });
    if (type == null) {
      return Center(child: Text(AppLocalizations.of(context)!.searchPrompt));
    }
    return FileListWidget(
      type: type!,
      conversation: conversation,
      userId: userId,
      keyword: query.trim(),
    );
  }
}

enum FileListType { all, my, conversation, user }

class FileListWidget extends StatefulWidget {
  final FileListType type;
  final Conversation? conversation;
  final String? userId;
  final String? keyword;

  const FileListWidget({
    super.key,
    required this.type,
    this.conversation,
    this.userId,
    this.keyword,
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
    if (widget.conversation != oldWidget.conversation ||
        widget.userId != oldWidget.userId ||
        widget.keyword != oldWidget.keyword) {
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
      if (widget.keyword != null && widget.keyword!.isNotEmpty) {
        Imclient.searchMyFiles(widget.keyword!, _beforeMessageUid, FileRecordOrder.TIME_DESC, 20, onSuccess, onError);
      } else {
        Imclient.getMyFiles(_beforeMessageUid, FileRecordOrder.TIME_DESC, 20, onSuccess, onError);
      }
    } else {
      if (widget.keyword != null && widget.keyword!.isNotEmpty) {
        Imclient.searchFiles(
          widget.keyword!,
          _beforeMessageUid,
          FileRecordOrder.TIME_DESC,
          20,
          onSuccess,
          onError,
          conversation: widget.conversation,
          fromUser: widget.userId,
        );
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.deleteFileRecordConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete),
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
          Fluttertoast.showToast(msg: AppLocalizations.of(context)!.fileRecordDeleted);
        }
      },
      (errorCode) {
        if (mounted) {
          Fluttertoast.showToast(msg: AppLocalizations.of(context)!.deleteFileRecordFailed);
        }
      },
    );
  }

  bool _canDelete(FileRecord file) {
    return file.userId == Imclient.currentUserId;
  }

  String _senderName(UserViewModel userViewModel, FileRecord file) {
    final userId = file.userId;
    if (userId == null || userId.isEmpty) {
      return '';
    }
    final user = userViewModel.getUserInfo(userId);
    return user.displayName?.emptyToNull ?? user.name.emptyToNull ?? userId;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider(
      create: (_) => UserViewModel(),
      child: Consumer<UserViewModel>(
        builder: (context, userViewModel, child) {
          if (_files.isEmpty && !_isLoading) {
            return Center(child: Text(l10n.noFiles));
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
                final sender = _senderName(userViewModel, file);
                final subtitleParts = [
                  if (sender.isNotEmpty) sender,
                  Utilities.formatSize(file.size),
                  Utilities.formatTime(context, file.timestamp),
                ];
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file, size: 40),
                  title: Text(file.name ?? l10n.unknownFile, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(subtitleParts.join('  ')),
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
          );
        },
      ),
    );
  }
}


