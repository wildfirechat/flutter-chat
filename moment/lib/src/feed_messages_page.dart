import 'package:flutter/material.dart';
import 'package:imclient/message/message.dart';
import 'package:moment/client/moment_comment_content.dart';
import 'package:moment/client/moment_feed_content.dart';
import 'package:moment/client/momentclient.dart';

import 'feed_detail_page.dart';
import 'moment_time.dart';
import 'widgets/moment_page_scaffold.dart';
import 'widgets/moment_widgets.dart';

/// 朋友圈消息列表页（收到的评论/点赞/提醒）。
class FeedMessagesPage extends StatefulWidget {
  const FeedMessagesPage({super.key});

  @override
  State<FeedMessagesPage> createState() => _FeedMessagesPageState();
}

class _FeedMessagesPageState extends State<FeedMessagesPage> {
  final List<Message> _messages = [];
  bool _loading = false;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    final fromIndex =
        refresh ? 0 : (_messages.isEmpty ? 0 : _messages.last.messageId);
    final messages = await MomentClient.getMessages(fromIndex, refresh);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasMore = messages.length >= 100;
      // SDK 返回为最新在前，与微信消息页一致（顶部最新，向下加载更早）。
      if (refresh) {
        _messages
          ..clear()
          ..addAll(messages);
      } else {
        _messages.addAll(messages);
      }
    });
    if (refresh) {
      MomentClient.clearUnreadStatus();
      MomentClient.updateLastReadTimestamp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MomentPageScaffold(
      appBar: AppBar(title: const Text('消息')),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification &&
              n.metrics.extentAfter < 200 &&
              _hasMore &&
              !_loading) {
            _load();
          }
          return false;
        },
        child: ListView.separated(
          itemCount: _messages.length + (_loading ? 1 : 0),
          separatorBuilder: (_, __) =>
              const Divider(height: 0.5, thickness: 0.5),
          itemBuilder: (context, index) {
            if (index == _messages.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }
            return _buildItem(_messages[index]);
          },
        ),
      ),
    );
  }

  Widget _buildItem(Message message) {
    final content = message.content;
    String sender = message.fromUser;
    String? text;
    bool isPraise = false;
    bool isMention = false;
    int feedId = 0;
    String? feedPreview;
    String? feedThumb;

    if (content is MomentCommentMessageContent) {
      sender = content.sender;
      feedId = content.feedId;
      isPraise = content.type == WFMCommentType.WFMComment_Thumbup_Type;
      text = isPraise ? null : content.text;
      feedPreview = content.feedText;
      if ((content.feedMedias ?? []).isNotEmpty) {
        final m = content.feedMedias!.first;
        feedThumb = (m.thumbUrl ?? '').isNotEmpty ? m.thumbUrl : m.mediaUrl;
      }
    } else if (content is MomentFeedMessageContent) {
      sender = content.sender;
      feedId = content.feedId;
      isMention = true;
      feedPreview = content.text;
      if ((content.medias ?? []).isNotEmpty) {
        final m = content.medias!.first;
        feedThumb = (m.thumbUrl ?? '').isNotEmpty ? m.thumbUrl : m.mediaUrl;
      }
    }

    return InkWell(
      onTap: () {
        if (feedId > 0) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => FeedDetailPage(feedId: feedId),
          ));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MomentAvatar(sender, size: 46),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MomentUserName(sender, fontSize: 14),
                  const SizedBox(height: 3),
                  Text(
                    isPraise
                        ? '赞了你的朋友圈'
                        : isMention
                            ? '在评论中提到了你'
                            : (text ?? ''),
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    MomentTime.formatMessageTime(message.serverTime),
                    style: const TextStyle(fontSize: 12, color: Colors.black38),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildFeedPreview(feedPreview, feedThumb),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedPreview(String? preview, String? thumb) {
    if ((thumb ?? '').isNotEmpty) {
      return MomentNetworkImage(thumb!, width: 56, height: 56);
    }
    return Container(
      width: 56,
      height: 56,
      color: kMomentCommentBg,
      padding: const EdgeInsets.all(4),
      child: Text(
        preview ?? '',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: Colors.black54),
      ),
    );
  }
}
