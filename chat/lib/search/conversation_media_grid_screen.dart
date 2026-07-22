import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/conversation/mm_preview_view.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/utils/media_url_redirector.dart';

/// 会话图片与视频网格页：3 列方形缩略图，点击全屏预览（分页见 conversation_links_screen 模式）。
class ConversationMediaGridScreen extends StatelessWidget {
  final Conversation conversation;

  const ConversationMediaGridScreen(this.conversation, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: l10n.searchMedia,
              onBack: () => Navigator.of(context).maybePop(),
            )
          : AppBar(
              title: Text(l10n.searchMedia),
            ),
      body: ConversationMediaGridView(conversation),
    );
  }
}

/// 图片与视频网格内容（无 Scaffold/AppBar），供搜索面板等场景内嵌。
class ConversationMediaGridView extends StatefulWidget {
  final Conversation conversation;

  const ConversationMediaGridView(this.conversation, {super.key});

  @override
  State<ConversationMediaGridView> createState() =>
      _ConversationMediaGridViewState();
}

class _ConversationMediaGridViewState extends State<ConversationMediaGridView> {
  static const int _pageSize = 30;
  static const List<int> _mediaTypes = [
    MESSAGE_CONTENT_TYPE_IMAGE,
    MESSAGE_CONTENT_TYPE_VIDEO,
  ];

  final GlobalKey<MMPreviewViewState> _previewKey =
      GlobalKey<MMPreviewViewState>();

  final List<Message> _media = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _fromMessageId = 0;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await Imclient.getMessages(
        widget.conversation,
        _fromMessageId,
        _pageSize,
        contentTypes: _mediaTypes,
      );

      if (mounted) {
        setState(() {
          _media.addAll(messages);
          _isLoading = false;
          if (messages.isNotEmpty) {
            _fromMessageId = messages.last.messageId;
          }
          if (messages.length < _pageSize) {
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

  /// 全屏预览；预览里翻到两端时继续向前/向后翻页加载
  void _openPreview(int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => MMPreviewView(
          List.of(_media),
          defaultIndex: index,
          pageToEnd: (fromIndex, tail) {
            // tail=true 翻到最新的，加载更新；否则加载更旧
            Imclient.getMessages(
              widget.conversation,
              fromIndex,
              tail ? -_pageSize : _pageSize,
              contentTypes: _mediaTypes,
            ).then((value) {
              if (value.isNotEmpty) {
                _previewKey.currentState?.onLoadMore(value, !tail);
              }
            });
          },
          key: _previewKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _media.isEmpty && !_isLoading
        ? Center(child: Text(l10n.noSearchResult))
        : NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (!_isLoading &&
                  _hasMore &&
                  scrollInfo.metrics.pixels >=
                      scrollInfo.metrics.maxScrollExtent - 200) {
                _loadMore();
              }
              return false;
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: _media.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _media.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                final message = _media[index];
                return GestureDetector(
                  onTap: () => _openPreview(index),
                  child: _MediaCell(message),
                );
              },
            ),
          );
  }
}

class _MediaCell extends StatelessWidget {
  final Message message;

  const _MediaCell(this.message);

  @override
  Widget build(BuildContext context) {
    final content = message.content;
    final isVideo = content is VideoMessageContent;

    Widget thumb;
    final thumbnail = content is ImageMessageContent
        ? content.thumbnail
        : content is VideoMessageContent
            ? content.thumbnail
            : null;
    final remoteUrl = content is ImageMessageContent
        ? content.remoteUrl
        : content is VideoMessageContent
            ? content.remoteUrl
            : null;

    if (thumbnail != null) {
      thumb = Image.memory(thumbnail, fit: BoxFit.cover);
    } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
      thumb = Image.network(
        MediaUrlRedirector.redirect(remoteUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    } else {
      thumb = _placeholder(context);
    }

    return Container(
      color: context.colors.sectionGap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          thumb,
          if (isVideo)
            const Positioned(
              right: 4,
              bottom: 4,
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 20,
                shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: context.colors.sectionGap,
      child: Icon(Icons.image_outlined, color: context.colors.textTertiary),
    );
  }
}
