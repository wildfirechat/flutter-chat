import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:momentclient/momentclient.dart';

import 'feed_messages_page.dart';
import 'moment_config.dart';
import 'moment_media_picker.dart';
import 'moment_upload.dart';
import 'moment_user_cache.dart';
import 'publish_feed_page.dart';
import 'widgets/comment_input_sheet.dart';
import 'widgets/feed_item_widget.dart';
import 'widgets/image_preview_page.dart';
import 'widgets/moment_widgets.dart';

/// 朋友圈主列表页。
///
/// [userId] 为空表示“朋友圈”首页（含顶部背景/头像/未读消息条/发布入口）；
/// 非空表示某个用户的朋友圈主页。
class FeedListPage extends StatefulWidget {
  final String? userId;

  /// PC 多窗口场景的外部刷新信号（feedId：刷新单条；null：全量刷新）。
  final Stream<int?>? refreshStream;

  const FeedListPage({super.key, this.userId, this.refreshStream});

  @override
  State<FeedListPage> createState() => _FeedListPageState();
}

class _FeedListPageState extends State<FeedListPage> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  StreamSubscription<int?>? _refreshSub;

  List<Feed> _feeds = [];
  bool _loading = false;
  bool _hasMore = false;
  MomentProfiles? _profile;
  int _unreadCount = 0;

  /// 顶部标题栏不透明度（0=全透明叠在封面上，1=不透明标题栏），
  /// 随封面滚出视口而淡入（对齐微信）。
  double _headerOpacity = 0;

  String get _selfUserId => Imclient.currentUserId;

  bool get _isHome => widget.userId == null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateHeaderOpacity);
    _restoreCache();
    _loadFeeds(refresh: true);
    if (_isHome) {
      _loadProfile();
      _loadUnread();
    }
    _refreshSub = widget.refreshStream?.listen((feedId) {
      if (!mounted) return;
      if (feedId == null) {
        _loadFeeds(refresh: true);
        _loadUnread();
      } else {
        _refreshFeed(feedId);
      }
    });
  }

  /// 封面高 300：滚到最后一个工具栏高度区间内时，标题栏从透明渐变为不透明。
  void _updateHeaderOpacity() {
    const fadeStart = 300.0 - kToolbarHeight * 2;
    const fadeEnd = 300.0 - kToolbarHeight;
    final opacity =
        ((_scrollController.offset - fadeStart) / (fadeEnd - fadeStart))
            .clamp(0.0, 1.0);
    if (opacity != _headerOpacity) {
      setState(() => _headerOpacity = opacity);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateHeaderOpacity);
    _refreshSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ 数据

  Future<void> _restoreCache() async {
    final cached = await MomentClient.restoreCache(userId: widget.userId);
    if (cached.isNotEmpty && mounted) {
      setState(() => _feeds = cached);
    }
  }

  void _loadFeeds({bool refresh = false}) {
    if (_loading) return;
    final fromIndex = refresh ? 0 : (_feeds.isEmpty ? 0 : (_feeds.last.feedId ?? 0));
    setState(() => _loading = true);
    MomentClient.getFeeds(fromIndex, _pageSize, widget.userId, (feeds) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasMore = feeds.length >= _pageSize;
        if (refresh) {
          _feeds = feeds;
        } else {
          _feeds = [..._feeds, ...feeds];
        }
      });
    }, (errorCode) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('加载失败($errorCode)');
    });
  }

  void _refreshFeed(int feedId) {
    MomentClient.getFeed(feedId, (feed) {
      if (!mounted) return;
      setState(() {
        final index = _feeds.indexWhere((f) => f.feedId == feedId);
        if (index >= 0) {
          _feeds[index] = feed;
        }
      });
    }, (_) {});
  }

  void _loadProfile() {
    MomentClient.getUserProfile((profile) {
      if (!mounted) return;
      setState(() => _profile = profile);
    }, (_) {}, userId: widget.userId);
  }

  void _loadUnread() {
    MomentClient.getUnreadCount().then((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  // ------------------------------------------------------------------ 交互

  void _onToggleLike(Feed feed, bool liked) {
    final feedId = feed.feedId;
    if (feedId == null) return;
    if (liked) {
      // 取消赞：找到自己的点赞记录并删除。
      try {
        final mine = feed.comments!.firstWhere((c) =>
            c.type == WFMCommentType.WFMComment_Thumbup_Type &&
            c.sender == _selfUserId);
        final commentId = mine.commentId;
        if (commentId == null) return;
        MomentClient.deleteComment(commentId, feedId, () {
          _refreshFeed(feedId);
        }, (code) => _toast('操作失败($code)'));
      } catch (_) {}
    } else {
      MomentClient.postComment(WFMCommentType.WFMComment_Thumbup_Type, feedId)
          .then((_) => _refreshFeed(feedId))
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
      _refreshFeed(feedId);
    } catch (e) {
      _toast('评论失败($e)');
    }
  }

  void _onDeleteComment(Feed feed, Comment comment) {
    final feedId = feed.feedId;
    final commentId = comment.commentId;
    if (feedId == null || commentId == null) return;
    MomentClient.deleteComment(commentId, feedId, () {
      _refreshFeed(feedId);
    }, (code) => _toast('删除失败($code)'));
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
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              MomentClient.deleteFeed(feedId, () {
                if (!mounted) return;
                setState(() => _feeds.removeWhere((f) => f.feedId == feedId));
              }, (code) => _toast('删除失败($code)'));
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _onTapUser(String userId) {
    if (userId.isEmpty || userId == widget.userId) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FeedListPage(userId: userId),
    ));
  }

  void _onTapMedia(Feed feed, int index) {
    ImagePreviewPage.open(context, feed.medias ?? [], index);
  }

  Future<void> _onPublish() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Center(child: Text('从相册选择')),
              onTap: () => Navigator.of(ctx).pop('media'),
            ),
            ListTile(
              title: const Center(child: Text('发表文字')),
              onTap: () => Navigator.of(ctx).pop('text'),
            ),
            ListTile(
              title: const Center(child: Text('取消')),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    List<MomentPickedMedia> medias = const [];
    if (action == 'media') {
      try {
        medias = await MomentKit.mediaPicker(context, maxCount: 9);
      } catch (e) {
        _toast('打开相册失败($e)');
        return;
      }
      if (medias.isEmpty || !mounted) return;
    }
    final published = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => PublishFeedPage(initialMedias: medias),
    ));
    if (published == true) {
      _loadFeeds(refresh: true);
    }
  }

  Future<void> _onTapBackground() async {
    if (!_isHome) return;
    final medias = await MomentKit.mediaPicker(context, maxCount: 1);
    if (medias.isEmpty || !mounted) return;
    try {
      final url = await uploadMomentMedia(medias.first);
      MomentClient.updateMyProfile(
          WFMUpdateUserProfileType.WFMUpdateUserProfileType_BackgroudUrl,
          url, null, () {
        _loadProfile();
      }, (code) => _toast('设置失败($code)'));
    } catch (e) {
      _toast('上传失败($e)');
    }
  }

  void _openFeedMessages() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FeedMessagesPage()))
        .then((_) => _loadUnread());
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 首页不用 AppBar：封面图顶到窗口上沿（对齐微信），
      // 标题和发布按钮以浮层形式叠在封面上。
      appBar: _isHome
          ? null
          : AppBar(
              title: ListenableBuilder(
                listenable: MomentUserCache.instance,
                builder: (context, _) => Text(
                    MomentUserCache.instance.displayNameOf(widget.userId!)),
              ),
              elevation: 0,
            ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              _loadFeeds(refresh: true);
              if (_isHome) _loadUnread();
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollEndNotification &&
                    _scrollController.position.extentAfter < 200 &&
                    _hasMore &&
                    !_loading) {
                  _loadFeeds();
                }
                return false;
              },
              // 内容居中显示，最大宽度 640（对齐微信 PC 的居中栏）
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: (_isHome ? 1 : 0) + _feeds.length + 1,
                    itemBuilder: (context, index) {
                      if (_isHome) {
                        if (index == 0) return _buildHeader();
                        index -= 1;
                      }
                      if (index == _feeds.length) return _buildFooter();
                      final feed = _feeds[index];
                      return FeedItemWidget(
                        key: ValueKey(feed.feedId),
                        feed: feed,
                        selfUserId: _selfUserId,
                        onTapMedia: _onTapMedia,
                        onTapUser: _onTapUser,
                        onToggleLike: _onToggleLike,
                        onComment: _onComment,
                        onDeleteComment: _onDeleteComment,
                        onDeleteFeed: _onDeleteFeed,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_isHome)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  final fgColor = Color.lerp(
                      Colors.white, theme.colorScheme.onSurface, _headerOpacity);
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor
                          .withValues(alpha: _headerOpacity),
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.1 * _headerOpacity),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: kToolbarHeight,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '朋友圈',
                              style: TextStyle(
                                color: fgColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                shadows: _headerOpacity < 0.5
                                    ? const [
                                        Shadow(
                                            color: Colors.black26,
                                            blurRadius: 4)
                                      ]
                                    : null,
                              ),
                            ),
                            Positioned(
                              right: 4,
                              child: IconButton(
                                icon: Icon(Icons.photo_camera_outlined,
                                    color: fgColor),
                                tooltip: '发表',
                                onPressed: _onPublish,
                                onLongPress: () async {
                                  final published = await Navigator.of(context)
                                      .push<bool>(MaterialPageRoute(
                                    builder: (_) => const PublishFeedPage(),
                                  ));
                                  if (published == true) {
                                    _loadFeeds(refresh: true);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        GestureDetector(
          onTap: _onTapBackground,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 300,
                width: double.infinity,
                child: (_profile?.backgroundUrl ?? '').isNotEmpty
                    ? MomentNetworkImage(_profile!.backgroundUrl!,
                        fit: BoxFit.cover)
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF9FB6D4), Color(0xFF7B93B8)],
                          ),
                        ),
                      ),
              ),
              Positioned(
                right: 12,
                bottom: -22,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18, right: 8),
                      child: Text(
                        MomentUserCache.instance.displayNameOf(_selfUserId),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: MomentAvatar(_selfUserId, size: 64, borderRadius: 4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        if (_unreadCount > 0)
          GestureDetector(
            onTap: _openFeedMessages,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 90, vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: kMomentCommentBg,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(
                child: Text(
                  '您有 $_unreadCount 条未读消息',
                  style: const TextStyle(fontSize: 13, color: kMomentNameColor),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFooter() {
    if (_feeds.isEmpty && !_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text('暂无朋友圈', style: TextStyle(color: Colors.black38)),
        ),
      );
    }
    if (!_hasMore && _feeds.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('没有更多了',
              style: TextStyle(fontSize: 12, color: Colors.black26)),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
