import 'package:flutter/material.dart';
import 'package:imclient/message/poll_message_content.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../ui_model/ui_message.dart';
import '../../poll/poll_detail_screen.dart';
import 'portrait_cell_builder.dart';

/// 投票消息 Cell Builder
///
/// 与 Android 端 conversation_item_poll_send/receive.xml 样式对齐
class PollCellBuilder extends PortraitCellBuilder {
  late PollMessageContent content;

  PollCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    content = model.message.content as PollMessageContent;
  }

  void _onTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PollDetailScreen.fromMessage(message: model.message),
      ),
    );
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: () => _onTap(context),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        // decoration: BoxDecoration(
        //   color: isSendMessage ? const Color(0xFF95EC69) : Colors.white,
        //   borderRadius: BorderRadius.circular(4),
        // ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题行：图标 + 标题
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 投票图标
                Icon(
                  Icons.poll,
                  size: 18,
                  color: const Color(0xFF576b95),
                ),
                const SizedBox(width: 6),
                // 标题
                Expanded(
                  child: Text(
                    content.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // 描述（如果有）
            if (content.desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                content.desc,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // 分隔线
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                height: 0.5,
                color: Color(0xFFe0e0e0),
              ),
            ),

            // 统计信息
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${content.totalVotes}${l10n.pollVotesCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
                // 状态标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: content.isEnded
                        ? const Color(0xFFF5F5F5)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    content.isEnded
                        ? l10n.pollStatusEnded
                        : l10n.pollStatusActive,
                    style: TextStyle(
                      fontSize: 11,
                      color: content.isEnded
                          ? const Color(0xFF999999)
                          : const Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ],
            ),

            // 剩余时间（如果有）
            if (content.getRemainingTimeText() != null) ...[
              const SizedBox(height: 4),
              Text(
                content.getRemainingTimeText()!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF999999),
                ),
              ),
            ],

            // 分隔线
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                height: 0.5,
                color: Color(0xFFe0e0e0),
              ),
            ),

            // 操作按钮
            Text(
              content.isEnded ? l10n.pollViewResult : l10n.pollJoinAction,
              style: TextStyle(
                fontSize: 14,
                color: content.isEnded
                    ? const Color(0xFF999999)
                    : const Color(0xFF576b95),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
