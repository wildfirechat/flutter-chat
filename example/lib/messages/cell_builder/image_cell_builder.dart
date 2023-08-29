import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import 'package:flutter/cupertino.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:wfc_example/messages/cell_builder/portrait_cell_builder.dart';

import '../message_cell.dart';
import '../message_model.dart';

class ImageCellBuilder extends PortraitCellBuilder {
  late ImageMessageContent imageMessageContent;
  ui.Image? uiImage;

  ImageCellBuilder(MessageState state, MessageModel model) : super(state, model) {
    imageMessageContent = model.message.content as ImageMessageContent;
    if(imageMessageContent.thumbnail != null) {
      ui.instantiateImageCodec(image.encodePng(imageMessageContent.thumbnail!))
          .then((codec) {
        codec.getNextFrame().then((frameInfo) {
          setState(() {
            uiImage = frameInfo.image;
          });
        });
      });
    }
  }

  @override
  Widget getContentAres() {
    if(uiImage != null) {
      return RawImage(image: uiImage,);
    } else if(imageMessageContent.remoteUrl != null) {
      return Image.network(imageMessageContent.remoteUrl!);
    } else {
      return const SizedBox(width: 48,height: 48,child: Center(child: CircularProgressIndicator(),),);
    }
  }
}
