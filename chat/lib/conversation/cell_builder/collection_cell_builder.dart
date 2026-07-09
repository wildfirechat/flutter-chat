import 'package:flutter/material.dart';
import 'package:imclient/message/collection_message_content.dart';
import 'package:chat/l10n/app_localizations.dart';

import '../../ui_model/ui_message.dart';
import 'portrait_cell_builder.dart';

/// 接龙消息 Cell Builder
/// 
/// 与 Android 端 conversation_item_collection_send/receive.xml 样式对齐
class CollectionCellBuilder extends PortraitCellBuilder {
  late CollectionMessageContent content;

  CollectionCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    content = model.message.content as CollectionMessageContent;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // 最多显示5条参与记录
    final entries = content.entries.where((e) => e.deleted == 0).toList();
    final displayEntries = entries.take(5).toList();
    final remainingCount = content.participantCount - displayEntries.length;
    
    return Container(
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
          // 标题行：图标 + 标题 + 参与人数
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 接龙图标
              Icon(
                Icons.format_list_numbered_rtl,
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
              const SizedBox(width: 4),
              // 参与人数
              Text(
                '${content.participantCount}${l10n.collectionPeopleCount}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF999999),
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
          
          // 参与记录预览
          if (displayEntries.isEmpty)
            // 空提示
            Text(
              l10n.collectionEmptyHint,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
              ),
            )
          else
            // 显示参与记录
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...displayEntries.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '$index. ${item.content}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF333333),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                
                // 更多提示
                if (remainingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.collectionMoreParticipants(remainingCount),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ),
              ],
            ),
          
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
            _getActionText(l10n),
            style: TextStyle(
              fontSize: 14,
              color: _getActionColor(),
            ),
          ),
        ],
      ),
    );
  }

  String _getActionText(AppLocalizations l10n) {
    if (content.status == 1) {
      return l10n.collectionStatusEnded;
    } else if (content.status == 2) {
      return l10n.collectionStatusCancelled;
    } else {
      return l10n.collectionJoinAction;
    }
  }

  Color _getActionColor() {
    if (content.status == 0) {
      return const Color(0xFF576b95);
    } else {
      return const Color(0xFF999999);
    }
  }
}
