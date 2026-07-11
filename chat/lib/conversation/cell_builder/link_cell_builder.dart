import 'package:flutter/material.dart';
import 'package:imclient/message/link_message_content.dart';

import '../../ui_model/ui_message.dart';
import '../../utils/media_url_redirector.dart';
import '../../utilities.dart';
import 'portrait_cell_builder.dart';
import 'package:chat/theme/app_typography.dart';

/// 链接消息 Cell Builder
///
/// 以卡片形式展示链接消息的标题、摘要、缩略图和 URL,点击可跳转。
class LinkCellBuilder extends PortraitCellBuilder {
  late LinkMessageContent linkContent;

  LinkCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    linkContent = model.message.content as LinkMessageContent;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hasThumbnail = linkContent.thumbnailUrl != null && linkContent.thumbnailUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => Utilities.openLink(context, linkContent.url),
      child: Container(
        width: (screenWidth * 0.75).clamp(240.0, 320.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasThumbnail)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: Image.network(
                  MediaUrlRedirector.redirect(linkContent.thumbnailUrl!),
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.link, size: 40, color: Colors.grey),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (linkContent.title.isNotEmpty)
                    Text(
                      linkContent.title,
                      style: AppText.lg.copyWith(fontWeight: FontWeight.w600, color: Color(0xFF576b95)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (linkContent.contentDigest.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      linkContent.contentDigest,
                      style: AppText.sm.copyWith(color: Color(0xFF888888)),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (linkContent.url.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.link, size: 12, color: Color(0xFFAAAAAA)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            linkContent.url,
                            style: AppText.xs.copyWith(color: Color(0xFFAAAAAA)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
