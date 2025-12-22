import 'dart:io';
import 'package:flutter/material.dart';
import 'package:imclient/message/sticker_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import '../../ui_model/ui_message.dart';

class StickerCellBuilder extends PortraitCellBuilder {
  late StickerMessageContent stickerContent;

  StickerCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    stickerContent = model.message.content as StickerMessageContent;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    Widget imageWidget;
    
    if (stickerContent.localPath != null && stickerContent.localPath!.isNotEmpty) {
      if (stickerContent.localPath!.startsWith('assets/')) {
        imageWidget = Image.asset(stickerContent.localPath!);
      } else {
        imageWidget = Image.file(File(stickerContent.localPath!));
      }
    } else if (stickerContent.remoteUrl != null && stickerContent.remoteUrl!.isNotEmpty) {
      imageWidget = Image.network(stickerContent.remoteUrl!);
    } else {
      imageWidget = const Icon(Icons.broken_image, size: 64, color: Colors.grey);
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
      child: imageWidget,
    );
  }
}
