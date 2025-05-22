import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import 'package:imclient/message/image_message_content.dart';
import 'package:wfc_example/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:wfc_example/conversation/message_cell.dart';

import '../../ui_model/ui_message.dart';

class ImageCellBuilder extends PortraitCellBuilder {
  late ImageMessageContent imageMessageContent;
  ui.Image? uiImage;

  ImageCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    imageMessageContent = model.message.content as ImageMessageContent;
    if (imageMessageContent.thumbnail != null) {
      if (model.thumbnailImage != null) {
        uiImage = model.thumbnailImage!;
      } else {
        // TODO
        // ui.instantiateImageCodec(image.encodePng(imageMessageContent.thumbnail!)).then((codec) {
        //   codec.getNextFrame().then((frameInfo) {
        //     setState(() {
        //       uiImage = frameInfo.image;
        //       model.thumbnailImage = frameInfo.image;
        //     });
        //   });
        // });
      }
    }
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    if (uiImage != null) {
      return RawImage(
        image: uiImage,
      );
    } else if (imageMessageContent.remoteUrl != null) {
      return Image.network(imageMessageContent.remoteUrl!);
    } else {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
  }
}
