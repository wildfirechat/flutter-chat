import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:momentclient/momentclient.dart';

import 'moment_user_cache.dart';
import 'widgets/comment_input_sheet.dart';
import 'widgets/feed_item_widget.dart';
import 'widgets/image_preview_page.dart';
import 'feed_list_page.dart';

/// 单条朋友圈详情页。
class FeedDetailPage extends StatefulWidget {
  final int feedId;

  const FeedDetailPage({super.key, required this.feedId});

  @override
  State<FeedDetailPage> createState() => _FeedDetailPageState();
}

class _FeedDetailPageState extends State<FeedDetailPage> {
  Feed? _feed;
  bool _failed = false;

  String get _selfUserId => Imclient.currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    MomentClient.getFeed(widget.feedId, (feed) {
      if (!mounted) return;
      setState(() {
        _feed = feed;
        _failed = false;
      });
    }, (code) {
      if (!mounted) return;
      setState(() => _failed = true);
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  void _onToggleLike(Feed feed, bool liked) {
    final feedId = feed.feedId;
    if (feedId == null) return;
    if (liked) {
      try {
        final mine = feed.comments!.firstWhere((c) =>
            c.type == WFMCommentType.WFMComment_Thumbup_Type &&
            c.sender == _selfUserId);
        final commentId = mine.commentId;
        if (commentId == null) return;
        MomentClient.deleteComment(commentId, feedId, _load,
            (code) => _toast('操作失败($code)'));
      } catch (_) {}
    } else {
      MomentClient.postComment(WFMCommentType.WFMComment_Thumbup_Type, feedId)
          .then((_) => _load())
          .catchError((e) => _toast('操作失败($e)'));
    }
  }

  Future<void> _onComment(Feed feed, Comment? replyTo) async {
    final feedId = feed.feedId;
    if (feedId == null) return;
    final hint = replyTo == null
        ? '评论'
        : '回复 ${MomentUserCache.instance.displayNameOf(replyTo.sender)}';
    final text = await CommentInputSheet.show(context, hint: hint);
    if (text == null || text.isEmpty) return;
    try {
      await MomentClient.postComment(
        WFMCommentType.WFMComment_Comment_Type,
        feedId,
        text: text,
        replyCommentId: replyTo?.commentId,
        replyTo: replyTo?.sender,
      );
      _load();
    } catch (e) {
      _toast('评论失败($e)');
    }
  }

  void _onDeleteComment(Feed feed, Comment comment) {
    final feedId = feed.feedId;
    final commentId = comment.commentId;
    if (feedId == null || commentId == null) return;
    MomentClient.deleteComment(
        commentId, feedId, _load, (code) => _toast('删除失败($code)'));
  }

  void _onDeleteFeed(Feed feed) {
    final feedId = feed.feedId;
    if (feedId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('确定删除这条朋友圈吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              MomentClient.deleteFeed(feedId, () {
                if (mounted) Navigator.of(context).pop();
              }, (code) => _toast('删除失败($code)'));
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    return Scaffold(
      appBar: AppBar(title: const Text('详情')),
      body: feed == null
          ? Center(
              child: _failed
                  ? const Text('内容不存在或已删除',
                      style: TextStyle(color: Colors.black38))
                  : const CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              child: FeedItemWidget(
                feed: feed,
                selfUserId: _selfUserId,
                onTapMedia: (f, i) =>
                    ImagePreviewPage.open(context, f.medias ?? [], i),
                onTapUser: (userId) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FeedListPage(userId: userId),
                  ));
                },
                onToggleLike: _onToggleLike,
                onComment: _onComment,
                onDeleteComment: _onDeleteComment,
                onDeleteFeed: _onDeleteFeed,
              ),
            ),
    );
  }
}
