import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/file_record.dart';
import 'package:chat/utilities.dart';
import 'package:chat/conversation/forward/show_pick_forward_target.dart';
import 'package:chat/conversation/pick_conversation_screen.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/app_shell.dart';

class FileRecordsScreen extends StatelessWidget {
  const FileRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppShell.isDesktopStyle
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
                  type: FileListType.all,
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
                  type: FileListType.my,
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
                    pushReplacementPage(
                      context,
                      FileListScreen(
                        title: AppLocalizations.of(context)!.chatFiles,
                        onBack: () => Navigator.of(context).maybePop(),
                        type: FileListType.conversation,
                        conversation: conversation,
                      ),
                    );
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
                      var conversation = Conversation(
                          conversationType: ConversationType.Single,
                          target: userId,
                          line: 0);
                      pushReplacementPage(
                        context,
                        FileListScreen(
                          title: AppLocalizations.of(context)!.userFiles,
                          onBack: () => Navigator.of(context).maybePop(),
                          type: FileListType.user,
                          conversation: conversation,
                          userId: userId,
                        ),
                      );
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
  final FileListType type;
  final Conversation? conversation;
  final String? userId;
  final bool showSearchAction;
  final VoidCallback? onBack;

  const FileListScreen({
    super.key,
    required this.title,
    required this.type,
    this.conversation,
    this.userId,
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
                  delegate: _FileSearchDelegate(
                    type: type,
                    conversation: conversation,
                    userId: userId,
                  ),
                );
              },
            ),
          ]
        : null;

    return Scaffold(
      appBar: AppShell.isDesktopStyle
          ? PcPageHeader(
              title: title,
              onBack: onBack,
              actions: actions,
            )
          : AppBar(
              title: Text(title),
              actions: actions,
            ),
      body: FileListWidget(
        type: type,
        conversation: conversation,
        userId: userId,
      ),
    );
  }
}

class _FileSearchDelegate extends SearchDelegate<FileRecord?> {
  final FileListType type;
  final Conversation? conversation;
  final String? userId;

  _FileSearchDelegate({
    required this.type,
    this.conversation,
    this.userId,
  });

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
    return FileListWidget(
      type: type,
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

class _FileListWidgetState extends State<FileListWidget>
    with AutomaticKeepAliveClientMixin {
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
        Imclient.searchMyFiles(widget.keyword!, _beforeMessageUid,
            FileRecordOrder.TIME_DESC, 20, onSuccess, onError);
      } else {
        Imclient.getMyFiles(_beforeMessageUid, FileRecordOrder.TIME_DESC, 20,
            onSuccess, onError);
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

  void _showFileActionMenu(BuildContext context, FileRecord file) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l10n.forward),
              onTap: () {
                Navigator.pop(ctx);
                _forwardFile(context, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n.downloadOrOpen),
              onTap: () {
                Navigator.pop(ctx);
                _downloadFile(context, file);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forwardFile(BuildContext context, FileRecord file) async {
    final l10n = AppLocalizations.of(context)!;
    final url = file.url;
    if (url.isEmpty) {
      Fluttertoast.showToast(msg: l10n.saveFailSourceMissing);
      return;
    }

    void showForward(String remoteUrl) {
      final content = FileMessageContent();
      content.name = file.name ?? 'file_${file.messageUid}';
      content.size = file.size;
      content.remoteUrl = remoteUrl;
      final message = Message();
      message.content = content;
      showPickForwardTarget(
        context,
        messages: [message],
        onSelected: (targets, comment) {
          _sendForwardMessages(context, targets, [message], comment);
        },
      );
    }

    Imclient.getAuthorizedMediaUrl(
      url,
      file.messageUid,
      MediaType.Media_Type_FILE.index,
      (authorizedUrl) {
        if (!context.mounted) return;
        showForward(authorizedUrl);
      },
      (errorCode) {
        if (!context.mounted) return;
        showForward(url);
      },
    );
  }

  void _sendForwardMessages(BuildContext context, List<Conversation> targets,
      List<Message> messages, String? comment) {
    final l10n = AppLocalizations.of(context)!;
    final total = targets.length * messages.length +
        (comment != null && comment.isNotEmpty ? targets.length : 0);
    int successCount = 0;
    int failCount = 0;

    void checkComplete() {
      if (successCount + failCount >= total) {
        if (failCount == 0) {
          Fluttertoast.showToast(msg: '${l10n.forward}${l10n.success}');
        } else {
          Fluttertoast.showToast(
              msg:
                  '${l10n.send}${l10n.success}: $successCount, ${l10n.setFail}$failCount');
        }
      }
    }

    if (comment != null && comment.isNotEmpty) {
      for (final target in targets) {
        Imclient.sendMessage(
          target,
          TextMessageContent(comment),
          successCallback: (_, __) {
            successCount++;
            checkComplete();
          },
          errorCallback: (_) {
            failCount++;
            checkComplete();
          },
        );
      }
    }
    for (final target in targets) {
      for (final msg in messages) {
        Imclient.sendMessage(
          target,
          msg.content,
          successCallback: (_, __) {
            successCount++;
            checkComplete();
          },
          errorCallback: (_) {
            failCount++;
            checkComplete();
          },
        );
      }
    }
  }

  Future<void> _downloadFile(BuildContext context, FileRecord file) async {
    final l10n = AppLocalizations.of(context)!;
    final fileName = file.name ?? 'file_${file.messageUid}';
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: l10n.saveFile,
        fileName: fileName,
      );
      if (outputFile == null) return;

      final url = file.url;
      if (url.isEmpty) {
        Fluttertoast.showToast(msg: l10n.saveFailSourceMissing);
        return;
      }

      Imclient.getAuthorizedMediaUrl(
        url,
        file.messageUid,
        MediaType.Media_Type_FILE.index,
        (authorizedUrl) async {
          try {
            final client = HttpClient();
            final request = await client
                .getUrl(Uri.parse(MediaUrlRedirector.redirect(authorizedUrl)));
            final response = await request.close();
            final bytes = await response
                .fold<List<int>>([], (prev, element) => prev..addAll(element));
            await File(outputFile).writeAsBytes(bytes);
            Fluttertoast.showToast(msg: l10n.saveSuccess);
          } catch (e) {
            Fluttertoast.showToast(msg: l10n.saveFail('$e'));
          }
        },
        (errorCode) {
          Fluttertoast.showToast(msg: l10n.saveFailSourceMissing);
        },
      );
    } catch (e) {
      Fluttertoast.showToast(msg: l10n.saveFail('$e'));
    }
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
          Fluttertoast.showToast(
              msg: AppLocalizations.of(context)!.fileRecordDeleted);
        }
      },
      (errorCode) {
        if (mounted) {
          Fluttertoast.showToast(
              msg: AppLocalizations.of(context)!.deleteFileRecordFailed);
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
                  scrollInfo.metrics.pixels ==
                      scrollInfo.metrics.maxScrollExtent) {
                _loadFiles();
              }
              return false;
            },
            child: ListView.separated(
              itemCount: _files.length + (_hasMore ? 1 : 0),
              separatorBuilder: (context, index) => const Divider(),
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
                  leading: Image.asset(
                    'assets/images/file_type/${Utilities.fileType(file.name ?? '')}.png',
                    width: 40,
                    height: 40,
                  ),
                  title: Text(
                    file.name ?? l10n.unknownFile,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sm,
                  ),
                  subtitle: Text(
                    subtitleParts.join('  '),
                    style: AppText.xs
                        .copyWith(color: context.colors.textSecondary),
                  ),
                  trailing: _canDelete(file)
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _deleteFile(file),
                        )
                      : null,
                  onTap: () => _showFileActionMenu(context, file),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
