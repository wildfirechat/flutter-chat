import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/quote_info.dart';

import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

import 'quoted_message_preview.dart';

class _QuoteThumb {
  const _QuoteThumb(this.bytes, this.isVideo);

  final Uint8List bytes;
  final bool isVideo;
}

/// 回查结果按被引用消息的 uid 缓存:一是列表滚动、hover 反复重建时不再过 SDK,
/// 二是没有缩略图的也记下来(存 null),不会每次重建都白查一遍。
/// 缩略图是几 KB 的 JPEG,条数封顶后按先进先出淘汰。
const int _kMaxCachedThumbs = 200;
final LinkedHashMap<int, _QuoteThumb?> _cache = LinkedHashMap();

void _remember(int messageUid, _QuoteThumb? thumb) {
  if (_cache.length >= _kMaxCachedThumbs && !_cache.containsKey(messageUid)) {
    _cache.remove(_cache.keys.first);
  }
  _cache[messageUid] = thumb;
}

_QuoteThumb? _thumbOf(Message? message) {
  final content = message?.content;
  if (content is ImageMessageContent) {
    final bytes = content.thumbnail;
    return bytes != null && bytes.isNotEmpty ? _QuoteThumb(bytes, false) : null;
  }
  if (content is VideoMessageContent) {
    final bytes = content.thumbnail;
    return bytes != null && bytes.isNotEmpty ? _QuoteThumb(bytes, true) : null;
  }
  return null;
}

/// 媒体类摘要都是 "[图片]"「[视频]」这种方括号开头的固定串。用它先挡掉纯文本引用,
/// 免得每条带引用的消息都去回查一次原消息;判错也只是多读一次本地库,不影响展示。
bool _mayHaveThumbnail(String digest) => digest.startsWith('[');

/// 缩略图边长。摘要文字是 12 号,这个尺寸让引用行大致是两行文字高。
const double _kThumbSize = 32;

/// 引用线宽度,以及引用线到摘要的间距。
const double _kQuoteBarWidth = 2;
const double _kQuoteBarGap = 8;

/// 消息气泡下面那一行"被引用的消息"(参考微信)。
///
/// 形态是 `发送者: 摘要`:引用的是图片/视频且回查得到缩略图时,摘要位置换成小图,
/// 拿不到缩略图才退回 "[图片]" 这样的文字摘要。桌面端在靠外的一侧竖一条引用线
/// (己方消息在右、对方消息在左),移动端只有文字。
///
/// 它挂在气泡外面而不是气泡里:引用是这条消息的附注,不跟气泡底色走,
/// 也就不会再把气泡撑宽。点击弹预览,长按/右键仍是本条消息的菜单。
class QuotedMessageLine extends StatefulWidget {
  const QuotedMessageLine({
    super.key,
    required this.quoteInfo,
    required this.isSendMessage,
    required this.showSender,
    this.onLongPress,
    this.onSecondaryTapUp,
  });

  final QuoteInfo quoteInfo;

  /// 己方消息:整行贴气泡右边,引用线也画在右边;对方消息左右镜像。
  final bool isSendMessage;

  /// 单聊里被引用的必然是这两个人之一,不必再重复一遍发送者(群聊才显示)。
  final bool showSender;

  /// 长按(移动端)/ 右键(桌面端)照旧弹本条消息的菜单,不被引用行吃掉。
  final GestureLongPressStartCallback? onLongPress;
  final GestureTapUpCallback? onSecondaryTapUp;

  @override
  State<QuotedMessageLine> createState() => _QuotedMessageLineState();
}

class _QuotedMessageLineState extends State<QuotedMessageLine> {
  final GlobalKey _lineKey = GlobalKey();
  _QuoteThumb? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant QuotedMessageLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quoteInfo.messageUid != widget.quoteInfo.messageUid) {
      _load();
    }
  }

  String get _digest => quoteDigestOneLine(widget.quoteInfo.messageDigest);

  void _load() {
    final uid = widget.quoteInfo.messageUid;
    if (!_mayHaveThumbnail(_digest)) {
      _thumb = null;
      return;
    }
    if (_cache.containsKey(uid)) {
      _thumb = _cache[uid];
      return;
    }
    _thumb = null;
    Imclient.getMessageByUid(uid).then((message) {
      final thumb = _thumbOf(message);
      _remember(uid, thumb);
      if (mounted && widget.quoteInfo.messageUid == uid && thumb != null) {
        setState(() => _thumb = thumb);
      }
    });
  }

  /// 引用行在窗口中的位置,预览浮层贴着它弹。
  Rect? get _lineRect {
    final renderBox = _lineKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return null;
    }
    return renderBox.localToGlobal(Offset.zero) & renderBox.size;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 整行(含引用线和它到文字的间距)都能点,不只是文字那一小块
      behavior: HitTestBehavior.opaque,
      onTap: () => showQuotedMessagePreview(context, widget.quoteInfo,
          anchor: _lineRect),
      onLongPressStart: widget.onLongPress,
      onSecondaryTapUp: widget.onSecondaryTapUp,
      child: isDesktopShell
          ? HoverBuilder(
              cursor: SystemMouseCursors.click,
              builder: (context, hovered) => _line(context, hovered),
            )
          : _line(context, false),
    );
  }

  Widget _line(BuildContext context, bool hovered) {
    // 引用线用 Border 而不是 Row 里塞一个 Container:边框天然跟外框等高,
    // 摘要折成两行(或换成缩略图)时不用再去对齐高度。
    final bar = BorderSide(
      color: context.colors.textTertiary,
      width: _kQuoteBarWidth,
    );
    final onRight = widget.isSendMessage;
    return Container(
      key: _lineKey,
      padding: EdgeInsets.only(
        left: isDesktopShell && !onRight ? _kQuoteBarGap : 0,
        right: isDesktopShell && onRight ? _kQuoteBarGap : 0,
      ),
      decoration: isDesktopShell
          ? BoxDecoration(
              border: Border(
                left: onRight ? BorderSide.none : bar,
                right: onRight ? bar : BorderSide.none,
              ),
            )
          : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: hovered ? context.colors.hoverOverlay : null,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: _summary(context),
        ),
      ),
    );
  }

  /// 发送者在左、内容在右:纯文本时两者是同一段文字,连着折行、超两行省略;
  /// 有缩略图时内容位置换成小图,发送者名太长先省略它,别把小图挤没。
  Widget _summary(BuildContext context) {
    final style = AppText.xs.copyWith(color: context.colors.textSecondary);
    final name = widget.showSender
        ? (widget.quoteInfo.userDisplayName ?? '').trim()
        : '';
    final thumb = _thumb;
    if (thumb == null) {
      return Text(
        name.isEmpty ? _digest : '$name: $_digest',
        style: style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (name.isNotEmpty)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '$name:',
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        _thumbnail(thumb),
      ],
    );
  }

  Widget _thumbnail(_QuoteThumb thumb) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.memory(
            thumb.bytes,
            width: _kThumbSize,
            height: _kThumbSize,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) =>
                const SizedBox(width: _kThumbSize, height: _kThumbSize),
          ),
          if (thumb.isVideo)
            Icon(
              Icons.play_circle_fill,
              size: _kThumbSize * 0.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
        ],
      ),
    );
  }
}
