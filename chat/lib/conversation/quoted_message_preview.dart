import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/quote_info.dart';

import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/media_preview_window/media_preview_window_manager.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_popover.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utilities.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/widgets/rich_text_message.dart';

import 'mm_preview_view.dart';

/// 气泡里引用块的一行摘要:去掉换行,让它在有限的行数里尽量多放内容
/// (与微信一致,引用条永远是连续的一段,不跟随原文分行)。
String quoteDigestOneLine(String? digest) =>
    (digest ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// 浮层宽度。比气泡窄一档,长文本折行后仍是一块规整的卡片。
const double _kPreviewWidth = 380;
const double _kPreviewMaxHeight = 420;
const double _kPreviewPadding = 16;

TextStyle _previewTextStyle(BuildContext context) =>
    AppText.lg.copyWith(color: context.colors.textPrimary, height: 1.4);

/// 卡片实际会有多高:正文排一遍 + 上下内边距,封顶到 [_kPreviewMaxHeight]。
/// 只用来判断锚点上方放不放得下(尾巴朝向要跟着落位),几像素误差无所谓。
double _previewCardHeight(BuildContext context, String body) {
  final painter = TextPainter(
    text: TextSpan(text: body, style: _previewTextStyle(context)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: _kPreviewWidth - _kPreviewPadding * 2);
  return math.min(painter.height + _kPreviewPadding * 2, _kPreviewMaxHeight);
}

/// 点击气泡里的引用块:参考微信,不跳会话,就地把被引用的消息弹出来看全。
///
/// 图片/视频交给媒体预览(桌面独立窗口 / 移动端全屏);其余类型弹一张只有正文的
/// 卡片——引用块最多两行,长文本必然被截断,这里是看到完整内容的唯一入口。
/// [anchor] 是引用块在窗口中的位置,桌面端浮层贴着它弹(点外部或 Esc 关闭)。
Future<void> showQuotedMessagePreview(
  BuildContext context,
  QuoteInfo quoteInfo, {
  Rect? anchor,
}) async {
  final message = await Imclient.getMessageByUid(quoteInfo.messageUid);
  if (!context.mounted) {
    return;
  }
  if (message == null) {
    showToast(msg: AppLocalizations.of(context)!.messageNotExist);
    return;
  }

  final content = message.content;
  if (content is ImageMessageContent || content is VideoMessageContent) {
    if (isDesktopShell) {
      // 参考微信:引用的图片/视频在独立窗口中预览(单条,不翻页)
      MediaPreviewWindowManager.instance.show(
        mediaItems: [message],
        defaultIndex: 0,
      );
    } else {
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) =>
              MMPreviewView(
            [message],
            defaultIndex: 0,
            pageToEnd: (fromIndex, tail) {},
          ),
        ),
      );
    }
    return;
  }

  // 文本/流式文本的 digest 就是完整正文;其余类型退回类型摘要([文件]:xxx 这类)。
  // 用当前消息重新算,而不是用发送时快照的 quoteInfo.messageDigest,原消息被
  // 撤回/编辑后预览到的才是最新状态。
  final body = await content.digest(message);
  if (!context.mounted) {
    return;
  }

  if (isDesktopShell && anchor != null) {
    // 小三角的朝向要和卡片落位一致,而落位取决于卡片多高,所以先把正文量一遍。
    final cardHeight = _previewCardHeight(context, body);
    final fitsAbove = anchor.top - cardHeight - 16 >= 0;
    await showPcPopover(
      context: context,
      anchor: anchor,
      width: _kPreviewWidth,
      maxHeight: _kPreviewMaxHeight,
      align: PcPopoverAlign.center,
      placement:
          fitsAbove ? PcPopoverPlacement.above : PcPopoverPlacement.below,
      tail: true,
      builder: (_) => _QuotedMessagePreview(text: body),
    );
    return;
  }

  // 移动端没有锚定浮层,用同样形态的居中卡片(无标题栏,点遮罩关闭)。
  await showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.6,
        ),
        child: _QuotedMessagePreview(text: body),
      ),
    ),
  );
}

/// 预览卡片的内容:完整正文,可选中复制、链接可点,超高则滚动。
class _QuotedMessagePreview extends StatelessWidget {
  final String text;

  const _QuotedMessagePreview({required this.text});

  @override
  Widget build(BuildContext context) {
    final style = _previewTextStyle(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(_kPreviewPadding),
      child: SelectionArea(
        child: RichTextMessageWidget(
          text: text,
          style: style,
          linkStyle: style.copyWith(
            color: context.colors.link,
            decoration: TextDecoration.underline,
          ),
          onLinkTap: (url) => Utilities.openLink(context, url),
        ),
      ),
    );
  }
}
