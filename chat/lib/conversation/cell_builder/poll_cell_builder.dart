import 'package:flutter/material.dart';
import 'package:imclient/message/poll_message_content.dart';
import 'package:chat/l10n/app_localizations.dart';

import '../../ui_model/ui_message.dart';
import '../../poll/poll_detail_screen.dart';
import '../../poll/poll_service.dart';
import 'portrait_cell_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

/// 投票消息气泡。
///
/// 气泡内一律继承气泡的前景色(见 [_onBubble]),层级用字重/透明度表达,不用色相 ——
/// 暗色下发送气泡是实心蓝,任何固定的灰或主色都会掉到读不出来。
class PollCellBuilder extends PortraitCellBuilder {
  late PollMessageContent content;

  PollCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    content = model.message.content as PollMessageContent;
  }

  Color _onBubble(BuildContext context) =>
      isSendMessage ? context.colors.bubbleSentText : context.colors.bubbleReceivedText;

  void _onTap(BuildContext context) {
    if (!PollService.isAvailable) return;
    PollDetailScreen.showFromMessage(context, model.message);
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onBubble = _onBubble(context);
    final remaining = content.getRemainingTimeText();

    // 元信息:票数 · 状态 · 剩余时间,合成一行,不再堆三个色块
    final meta = <String>[
      '${content.totalVotes}${l10n.pollVotesCount}',
      content.isEnded ? l10n.pollStatusEnded : l10n.pollStatusActive,
      if (remaining != null && remaining.isNotEmpty) remaining,
    ].join(' · ');

    return InkWell(
      onTap: () => _onTap(context),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.poll, size: 16, color: onBubble),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    content.title,
                    style: AppText.base.copyWith(fontWeight: FontWeight.w600, color: onBubble),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (content.desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Opacity(
                opacity: 0.7,
                child: Text(
                  content.desc,
                  style: AppText.xs.copyWith(color: onBubble),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Opacity(
              opacity: 0.7,
              child: Text(meta, style: AppText.xs.copyWith(color: onBubble)),
            ),
            const SizedBox(height: 8),
            Opacity(opacity: 0.15, child: Divider(color: onBubble)),
            const SizedBox(height: 8),
            Text(
              content.isEnded ? l10n.pollViewResult : l10n.pollJoinAction,
              style: AppText.xs.copyWith(fontWeight: FontWeight.w500, color: onBubble),
            ),
          ],
        ),
      ),
    );
  }
}
