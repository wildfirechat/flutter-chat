import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';

import 'package:chat/theme/app_colors.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/theme/app_typography.dart';

/// 桌面端右栏的待转发消息预览:单条显示摘要(图片附缩略图),多条显示条数汇总。
///
/// 移动端的确认弹窗有自己的一套预览(带视频角标、缩略图字节),两者视觉不同,故未合并。
class ForwardMessagePreview extends StatelessWidget {
  final List<Message>? messages;
  final bool oneByOne;

  const ForwardMessagePreview(
      {super.key, required this.messages, required this.oneByOne});

  @override
  Widget build(BuildContext context) {
    final messages = this.messages;
    if (messages == null || messages.isEmpty) {
      return const SizedBox.shrink();
    }
    return messages.length == 1
        ? _buildSingle(context, messages.first)
        : _buildSummary(context, messages.length);
  }

  Widget _buildSingle(BuildContext context, Message message) {
    final thumbnail = _buildThumbnail(context, message);

    return FutureBuilder<String>(
      future: message.content.digest(message),
      builder: (context, snapshot) {
        final text = snapshot.data ?? AppLocalizations.of(context)!.loading;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.colors.inputBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: AppText.sm.copyWith(
                    color: context.colors.textSecondary,
                    height: 1.4,
                    decoration: TextDecoration.none),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              if (thumbnail != null) thumbnail,
            ],
          ),
        );
      },
    );
  }

  /// 图片消息优先用本地原图,其次用远端地址;其它类型不出图。
  Widget? _buildThumbnail(BuildContext context, Message message) {
    final content = message.content;
    if (content is! ImageMessageContent) return null;

    final localPath = content.localPath;
    final remoteUrl = content.remoteUrl;
    final ImageProvider image;
    if (localPath != null && File(localPath).existsSync()) {
      image = FileImage(File(localPath));
    } else if (remoteUrl != null) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      image = ResizeImage(
        CachedNetworkImageProvider(MediaUrlRedirector.redirect(remoteUrl)),
        width: (80 * dpr).ceil(),
        height: (80 * dpr).ceil(),
      );
    } else {
      return null;
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        image: DecorationImage(image: image, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, int count) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.inputBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.description_rounded,
              color: context.colors.iconSecondary, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  oneByOne ? l10n.forwardOneByOne : l10n.forwardCombined,
                  style: AppText.sm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.totalMessages('$count'),
                  style:
                      AppText.xs.copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
