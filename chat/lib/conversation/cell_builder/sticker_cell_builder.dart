import 'dart:io';
import 'package:flutter/material.dart';
import 'package:imclient/message/sticker_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:chat/utils/media_url_redirector.dart';
import '../../ui_model/ui_message.dart';

class StickerCellBuilder extends PortraitCellBuilder {
  late StickerMessageContent stickerContent;

  StickerCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    stickerContent = model.message.content as StickerMessageContent;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    Widget imageWidget;
    // 显示区域最大 150×150,按显示尺寸×dpr 解码，避免原图全尺寸解码占用大量内存
    double dpr = MediaQuery.of(context).devicePixelRatio;
    int cacheSize = (150 * dpr).ceil();

    if (stickerContent.localPath != null && stickerContent.localPath!.isNotEmpty) {
      if (stickerContent.localPath!.startsWith('assets/')) {
        imageWidget = Image.asset(stickerContent.localPath!);
      } else {
        imageWidget = Image.file(
          File(stickerContent.localPath!),
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
        );
      }
    } else if (stickerContent.remoteUrl != null && stickerContent.remoteUrl!.isNotEmpty) {
      imageWidget = Image.network(
        MediaUrlRedirector.redirect(stickerContent.remoteUrl!),
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
      );
    } else {
      imageWidget = const Icon(Icons.broken_image, size: 64, color: Colors.grey);
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
      child: imageWidget,
    );
  }
}
