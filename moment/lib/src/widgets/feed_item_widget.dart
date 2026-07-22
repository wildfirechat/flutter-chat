import 'package:flutter/material.dart';
import 'package:moment/client/momentclient.dart';

import '../moment_time.dart';
import 'comment_widget.dart';
import 'moment_widgets.dart';
import 'nine_grid_view.dart';

/// 单条朋友圈条目（列表页与详情页共用）。
class FeedItemWidget extends StatelessWidget {
  final Feed feed;

  /// 当前用户 id。
  final String selfUserId;

  /// 点击九宫格图片/视频。
  final void Function(Feed feed, int index)? onTapMedia;

  /// 点击用户名/头像（跳转该用户朋友圈主页）。
  final void Function(String userId)? onTapUser;

  /// 赞/取消赞。
  final void Function(Feed feed, bool liked)? onToggleLike;

  /// 评论该条 feed（[replyTo] 非空表示回复某条评论）。
  final void Function(Feed feed, Comment? replyTo)? onComment;

  /// 删除自己的评论。
  final void Function(Feed feed, Comment comment)? onDeleteComment;

  /// 删除该条 feed。
  final void Function(Feed feed)? onDeleteFeed;

  const FeedItemWidget({
    super.key,
    required this.feed,
    required this.selfUserId,
    this.onTapMedia,
    this.onTapUser,
    this.onToggleLike,
    this.onComment,
    this.onDeleteComment,
    this.onDeleteFeed,
  });

  bool get _likedBySelf => (feed.comments ?? []).any((c) =>
      c.type == WFMCommentType.WFMComment_Thumbup_Type &&
      c.sender == selfUserId);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MomentAvatar(feed.sender, onTap: () => onTapUser?.call(feed.sender)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MomentUserName(feed.sender,
                          onTap: () => onTapUser?.call(feed.sender)),
                      if ((feed.text ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(feed.text!,
                            style: const TextStyle(
                                fontSize: 15, color: Colors.black87, height: 1.25)),
                      ],
                      if ((feed.medias ?? []).isNotEmpty) ...[
                        const SizedBox(height: 6),
                        NineGridView(
                          entries: feed.medias!,
                          onTapItem: (i) => onTapMedia?.call(feed, i),
                        ),
                      ],
                      if (feed.type == WFMContentType.WFMContent_Link_Type)
                        _buildLinkCard(),
                      const SizedBox(height: 6),
                      _buildTimeRow(context),
                      CommentWidget(
                        feed: feed,
                        selfUserId: selfUserId,
                        onTapUser: onTapUser,
                        onReplyComment: (c) => onComment?.call(feed, c),
                        onDeleteComment: (c) => onDeleteComment?.call(feed, c),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 0.5, thickness: 0.5),
        ],
      ),
    );
  }

  Widget _buildLinkCard() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      color: kMomentCommentBg,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            color: Colors.white,
            child: const Icon(Icons.link, color: kMomentNameColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feed.extra ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(BuildContext context) {
    final isSelf = feed.sender == selfUserId;
    return Row(
      children: [
        Text(
          MomentTime.format(feed.serverTime ?? 0),
          style: const TextStyle(fontSize: 12, color: Colors.black38),
        ),
        if (isSelf) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onDeleteFeed?.call(feed),
            child: const Text('删除',
                style: TextStyle(fontSize: 12, color: Colors.redAccent)),
          ),
        ],
        const Spacer(),
        _LikeCommentButton(
          liked: _likedBySelf,
          onLike: () => onToggleLike?.call(feed, _likedBySelf),
          onComment: () => onComment?.call(feed, null),
        ),
      ],
    );
  }
}

/// “··”按钮 + 赞/评论弹出菜单。
class _LikeCommentButton extends StatelessWidget {
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const _LikeCommentButton({
    required this.liked,
    required this.onLike,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPopup(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: kMomentCommentBg,
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Icon(Icons.more_horiz, size: 18, color: kMomentNameColor),
      ),
    );
  }

  void _showPopup(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero, ancestor: overlay);
    final rect = Rect.fromLTWH(
        offset.dx - 170, offset.dy - 44, 170, box.size.height + 44);
    final value = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: [
        _buildItem(0, liked ? Icons.favorite : Icons.favorite_border,
            liked ? '取消' : '赞'),
        _buildItem(1, Icons.mode_comment_outlined, '评论'),
      ],
      color: const Color(0xFF4C4C4C),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
    if (value == 0) {
      onLike();
    } else if (value == 1) {
      onComment();
    }
  }

  PopupMenuItem<int> _buildItem(int value, IconData icon, String text) {
    return PopupMenuItem<int>(
      value: value,
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }
}
