import 'package:flutter/material.dart';
import 'package:imclient/message/collection_message_content.dart';
import 'package:chat/l10n/app_localizations.dart';

import '../../ui_model/ui_message.dart';
import 'portrait_cell_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

/// 接龙消息气泡:标题 + 前 5 条参与记录预览。
///
/// 与 [PollCellBuilder] 同一条规则:气泡内一律继承气泡前景色,层级用字重/透明度表达。
/// 点击进详情由 ConversationController 统一处理(与其他可点消息一致)。
class CollectionCellBuilder extends PortraitCellBuilder {
  static const int maxPreviewEntries = 5;

  late CollectionMessageContent content;

  CollectionCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    content = model.message.content as CollectionMessageContent;
  }

  Color _onBubble(BuildContext context) =>
      isSendMessage ? context.colors.bubbleSentText : context.colors.bubbleReceivedText;

  @override
  Widget buildMessageContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onBubble = _onBubble(context);

    final entries = content.entries.where((e) => e.deleted == 0).toList();
    final preview = entries.take(maxPreviewEntries).toList();
    final remaining = content.participantCount - preview.length;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.format_list_numbered_rtl, size: 16, color: onBubble),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  content.title,
                  style: AppText.base.copyWith(fontWeight: FontWeight.w600, color: onBubble),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Opacity(
                opacity: 0.7,
                child: Text(
                  '${content.participantCount}${l10n.collectionPeopleCount}',
                  style: AppText.xs.copyWith(color: onBubble),
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
          Opacity(opacity: 0.15, child: Divider(color: onBubble)),
          const SizedBox(height: 8),
          if (preview.isEmpty)
            Opacity(
              opacity: 0.7,
              child: Text(
                l10n.collectionEmptyHint,
                style: AppText.xs.copyWith(color: onBubble),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < preview.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${i + 1}. ${preview[i].content}',
                      style: AppText.xs.copyWith(color: onBubble),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (remaining > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Opacity(
                      opacity: 0.7,
                      child: Text(
                        l10n.collectionMoreParticipants(remaining),
                        style: AppText.xs.copyWith(color: onBubble),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Opacity(opacity: 0.15, child: Divider(color: onBubble)),
          const SizedBox(height: 8),
          Text(
            _actionText(l10n),
            style: AppText.xs.copyWith(fontWeight: FontWeight.w500, color: onBubble),
          ),
        ],
      ),
    );
  }

  String _actionText(AppLocalizations l10n) {
    switch (content.status) {
      case 1:
        return l10n.collectionStatusEnded;
      case 2:
        return l10n.collectionStatusCancelled;
      default:
        return l10n.collectionJoinAction;
    }
  }
}
