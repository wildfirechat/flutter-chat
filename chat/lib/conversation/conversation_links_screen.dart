import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/link_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';

import '../../utilities.dart';
import '../../viewmodel/user_view_model.dart';
import '../../l10n/app_localizations.dart';

/// 会话链接记录列表页
///
/// 展示指定会话中的所有链接消息,点击进入链接。
class ConversationLinksScreen extends StatefulWidget {
  final Conversation conversation;

  const ConversationLinksScreen(this.conversation, {super.key});

  @override
  State<ConversationLinksScreen> createState() => _ConversationLinksScreenState();
}

class _ConversationLinksScreenState extends State<ConversationLinksScreen> {
  List<Message> _links = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _fromMessageId = 0;

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await Imclient.getMessages(
        widget.conversation,
        _fromMessageId,
        20,
        contentTypes: [MESSAGE_CONTENT_TYPE_LINK],
      );

      if (mounted) {
        setState(() {
          _links.addAll(messages);
          _isLoading = false;
          if (messages.isNotEmpty) {
            _fromMessageId = messages.last.messageId;
          }
          if (messages.length < 20) {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _links.clear();
      _hasMore = true;
      _fromMessageId = 0;
      _isLoading = false;
    });
    await _loadLinks();
  }

  String _senderName(UserViewModel userViewModel, Message message) {
    final userId = message.fromUser;
    if (userId.isEmpty) return '';
    final user = userViewModel.getUserInfo(userId);
    return user.displayName?.emptyToNull ?? user.name.emptyToNull ?? userId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatLinks),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _links.isEmpty && !_isLoading
            ? Center(child: Text(l10n.noLinks))
            : NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  if (!_isLoading &&
                      _hasMore &&
                      scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                    _loadLinks();
                  }
                  return false;
                },
                child: ChangeNotifierProvider(
                  create: (_) => UserViewModel(),
                  child: Consumer<UserViewModel>(
                    builder: (context, userViewModel, child) {
                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _links.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (index == _links.length) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final message = _links[index];
                          final content = message.content as LinkMessageContent;
                          final sender = _senderName(userViewModel, message);
                          return ListTile(
                            leading: content.thumbnailUrl != null && content.thumbnailUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      content.thumbnailUrl!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _defaultLinkIcon(),
                                    ),
                                  )
                                : _defaultLinkIcon(),
                            title: Text(
                              content.title.isNotEmpty ? content.title : content.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                if (sender.isNotEmpty) sender,
                                if (content.contentDigest.isNotEmpty) content.contentDigest,
                                Utilities.formatTime(context, message.serverTime),
                              ].join('  '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () => Utilities.openLink(context, content.url),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }

  Widget _defaultLinkIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.link, color: Colors.grey),
    );
  }
}
