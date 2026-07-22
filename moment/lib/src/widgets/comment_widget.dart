import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moment/client/momentclient.dart';

import 'moment_widgets.dart';

/// 点赞 + 评论区（灰底区域）。
class CommentWidget extends StatelessWidget {
  final Feed feed;

  /// 点击某个用户名（跳转该用户朋友圈主页）。
  final void Function(String userId)? onTapUser;

  /// 回复某条评论。
  final void Function(Comment comment)? onReplyComment;

  /// 删除自己的评论。
  final void Function(Comment comment)? onDeleteComment;

  /// 当前用户 id。
  final String selfUserId;

  const CommentWidget({
    super.key,
    required this.feed,
    required this.selfUserId,
    this.onTapUser,
    this.onReplyComment,
    this.onDeleteComment,
  });

  List<Comment> get _praises => (feed.comments ?? [])
      .where((c) => c.type == WFMCommentType.WFMComment_Thumbup_Type)
      .toList();

  List<Comment> get _comments => (feed.comments ?? [])
      .where((c) => c.type == WFMCommentType.WFMComment_Comment_Type)
      .toList();

  /// 自己是否已赞。
  bool get likedBySelf =>
      _praises.any((c) => c.sender == selfUserId);

  @override
  Widget build(BuildContext context) {
    final praises = _praises;
    final comments = _comments;
    if (praises.isEmpty && comments.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: kMomentCommentBg,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (praises.isNotEmpty) _buildPraises(praises),
          if (praises.isNotEmpty && comments.isNotEmpty)
            const Divider(height: 8, thickness: 0.5),
          for (final c in comments) _buildCommentRow(context, c),
        ],
      ),
    );
  }

  Widget _buildPraises(List<Comment> praises) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.favorite_border, size: 14, color: kMomentNameColor),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Wrap(
            children: [
              for (var i = 0; i < praises.length; i++) ...[
                _userLink(praises[i].sender, fontSize: 14),
                if (i < praises.length - 1)
                  const Text('，', style: TextStyle(fontSize: 14, color: Colors.black87)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentRow(BuildContext context, Comment comment) {
    final isSelf = comment.sender == selfUserId;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isSelf) {
          _showSelfCommentMenu(context, comment);
        } else {
          onReplyComment?.call(comment);
        }
      },
      onLongPress: () => _showCommentLongPressMenu(context, comment),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _userLink(comment.sender, fontSize: 14),
            if ((comment.replyTo ?? '').isNotEmpty) ...[
              const Text('回复', style: TextStyle(fontSize: 14, color: Colors.black87)),
              _userLink(comment.replyTo!, fontSize: 14),
            ],
            const Text('：', style: TextStyle(fontSize: 14, color: Colors.black87)),
            Text(comment.text ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _userLink(String userId, {double fontSize = 14}) {
    return _TapableUserName(
      userId,
      fontSize: fontSize,
      onTap: () => onTapUser?.call(userId),
    );
  }

  void _showSelfCommentMenu(BuildContext context, Comment comment) {
    _showActionSheet(context, [
      _Action('删除', () => onDeleteComment?.call(comment)),
      _Action('复制', () {
        if ((comment.text ?? '').isNotEmpty) {
          Clipboard.setData(ClipboardData(text: comment.text!));
        }
      }),
    ]);
  }

  void _showCommentLongPressMenu(BuildContext context, Comment comment) {
    final actions = <_Action>[
      _Action('复制', () {
        if ((comment.text ?? '').isNotEmpty) {
          Clipboard.setData(ClipboardData(text: comment.text!));
        }
      }),
      _Action('回复', () => onReplyComment?.call(comment)),
    ];
    if (comment.sender == selfUserId) {
      actions.add(_Action('删除', () => onDeleteComment?.call(comment)));
    }
    _showActionSheet(context, actions);
  }

  void _showActionSheet(BuildContext context, List<_Action> actions) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final a in actions)
                ListTile(
                  title: Center(child: Text(a.title)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    a.onTap();
                  },
                ),
              ListTile(
                title: const Center(child: Text('取消')),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Action {
  final String title;
  final VoidCallback onTap;
  const _Action(this.title, this.onTap);
}

/// 可点击的用户名（监听用户缓存刷新展示名）。
class _TapableUserName extends StatelessWidget {
  final String userId;
  final double fontSize;
  final VoidCallback? onTap;

  const _TapableUserName(this.userId, {required this.fontSize, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MomentUserName(userId, fontSize: fontSize),
    );
  }
}
