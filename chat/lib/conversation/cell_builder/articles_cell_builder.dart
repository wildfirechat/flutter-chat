import 'package:flutter/material.dart';
import 'package:imclient/message/articles_message_content.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/pc/pc_platform.dart';

import '../../ui_model/ui_message.dart';
import '../../utilities.dart';
import 'portrait_cell_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/l10n/app_localizations.dart';

/// 图文消息 Cell Builder
///
/// 对齐微信公众号图文卡片:主文章大封面(有子文章时标题压在封面上),
/// 子文章逐行排列(标题在左、缩略图在右)。点击任意一篇打开它自己的链接
/// (移动端内嵌 WebView、桌面端外部浏览器,由 [Utilities.openLink] 分流)。
class ArticlesCellBuilder extends PortraitCellBuilder {
  late ArticlesMessageContent articlesContent;

  ArticlesCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    articlesContent = model.message.content as ArticlesMessageContent;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    final cardWidth = _cardWidth(context);
    final topArticle = articlesContent.topArticle;
    final subArticles = articlesContent.subArticles ?? const <Article>[];

    if (topArticle == null) {
      return _card(context, cardWidth, [_placeholder(context)]);
    }

    return _card(context, cardWidth, [
      _topArticle(context, topArticle, cardWidth, hasSubArticles: subArticles.isNotEmpty),
      for (final article in subArticles) ...[
        Divider(height: 1, thickness: 1, color: context.colors.hairlineSoft),
        _subArticle(context, article),
      ],
    ]);
  }

  /// 桌面端窗口很宽,按比例算会一路顶到上限,直接给固定宽度更稳定
  double _cardWidth(BuildContext context) {
    if (isDesktopShell) {
      return 340;
    }
    return (MediaQuery.of(context).size.width * 0.75).clamp(240.0, 320.0).toDouble();
  }

  Widget _card(BuildContext context, double width, List<Widget> children) {
    return Container(
      width: width,
      // 卡片自带底色:图文是卡片而非气泡文本,PortraitCellBuilder 已为图文去掉气泡内边距
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  /// 主文章:大封面。有子文章时标题压在封面底部(公众号多图文样式),
  /// 只有一篇时标题另起一行放在封面下方,便于完整展示。
  Widget _topArticle(BuildContext context, Article article, double width, {required bool hasSubArticles}) {
    const double coverHeight = 150;
    return _tappable(
      context,
      article.url,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              _cover(context, article.cover, width: width, height: coverHeight),
              if (hasSubArticles)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
                    // 封面明暗不可控,压一层自上而下加深的黑色渐变,保证白色标题可读
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xB3000000)],
                      ),
                    ),
                    child: Text(
                      article.title,
                      style: AppText.base.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          if (!hasSubArticles)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                article.title,
                style: AppText.base.copyWith(fontWeight: FontWeight.w500, color: context.colors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _subArticle(BuildContext context, Article article) {
    return _tappable(
      context,
      article.url,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                article.title,
                style: AppText.sm.copyWith(color: context.colors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: _cover(context, article.cover, width: 52, height: 52),
            ),
          ],
        ),
      ),
    );
  }

  /// 点击打开文章链接。url 为空时不做成可点,避免给出无效的点击反馈。
  Widget _tappable(BuildContext context, String url, Widget child) {
    if (url.isEmpty) {
      return child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Utilities.openLink(context, url),
      child: child,
    );
  }

  Widget _cover(BuildContext context, String url, {required double width, required double height}) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final fallback = Container(
      width: width,
      height: height,
      color: context.colors.inputBg,
      child: Icon(Icons.article_outlined, size: height > 80 ? 40 : 22, color: context.colors.textTertiary),
    );
    if (url.isEmpty) {
      return fallback;
    }
    return Image.network(
      MediaUrlRedirector.redirect(url),
      width: width,
      height: height,
      // 按显示尺寸×dpr 解码,避免原图全尺寸解码占用大量内存
      cacheWidth: (width * dpr).ceil(),
      cacheHeight: (height * dpr).ceil(),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Widget _placeholder(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_outlined, size: 24, color: context.colors.link),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              AppLocalizations.of(context)!.articlesPlaceholder,
              style: AppText.base.copyWith(color: context.colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
