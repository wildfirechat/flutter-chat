import 'package:flutter/material.dart';
import 'package:imclient/message/articles_message_content.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/pc/pc_platform.dart';

import '../../ui_model/ui_message.dart';
import 'portrait_cell_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

class ArticlesCellBuilder extends PortraitCellBuilder {
  late ArticlesMessageContent articlesContent;

  ArticlesCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    articlesContent = model.message.content as ArticlesMessageContent;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final articles = articlesContent.articles;

    return Container(
      width: (screenWidth * 0.75).clamp(240.0, 320.0),
      decoration: BoxDecoration(
        color: isSendMessage && isDesktopShell
            ? context.colors.bubbleSentDesktop
            : (isDesktopShell ? context.colors.bubbleReceivedDesktop : context.colors.bubbleReceived),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (articles.isNotEmpty) ...[
            // 首篇文章封面
            if (articles[0].thumbnailUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: Image.network(
                  MediaUrlRedirector.redirect(articles[0].thumbnailUrl),
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 100,
                    color: context.colors.inputBg,
                    child: Icon(Icons.article, size: 40, color: context.colors.textSecondary),
                  ),
                ),
              ),
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Text(
                articlesContent.title.isNotEmpty ? articlesContent.title : articles[0].title,
                style: AppText.lg.copyWith(fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 分隔线
            Divider(height: 1, color: context.colors.hairlineSoft),
            // 文章列表
            for (int i = 0; i < articles.length && i < 3; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        articles[i].digest.isNotEmpty ? articles[i].digest : articles[i].title,
                        style: AppText.sm.copyWith(color: context.colors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (articles[i].thumbnailUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          MediaUrlRedirector.redirect(articles[i].thumbnailUrl),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48),
                        ),
                      ),
                  ],
                ),
              ),
              if (i < articles.length - 1 && i < 2)
                Divider(height: 1, indent: 12, endIndent: 12, color: context.colors.hairlineSoft),
            ],
            if (articles.length > 3)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '还有 ${articles.length - 3} 篇文章',
                  style: AppText.xs.copyWith(color: context.colors.textSecondary),
                ),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.article, size: 24, color: context.colors.link),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      articlesContent.title.isNotEmpty ? articlesContent.title : '[图文]',
                      style: AppText.lg.copyWith(color: context.colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
