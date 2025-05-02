import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import 'package:imclient/message/video_message_content.dart';
import 'package:wfc_example/messages/cell_builder/portrait_cell_builder.dart';

import '../message_cell.dart';
import '../../ui_model/ui_message.dart';

class VideoCellBuilder extends PortraitCellBuilder {
  late VideoMessageContent videoMessageContent;
  ui.Image? uiImage;

  VideoCellBuilder(MessageCell cell, UIMessage model) : super(cell, model) {
    videoMessageContent = model.message.content as VideoMessageContent;
    if(videoMessageContent.thumbnail != null) {
      if(model.thumbnailImage != null) {
        uiImage = model.thumbnailImage;
      } else {
        // TODO
        // ui.instantiateImageCodec(
        //     image.encodePng(videoMessageContent.thumbnail!))
        //     .then((codec) {
        //   codec.getNextFrame().then((frameInfo) {
        //     setState(() {
        //       uiImage = frameInfo.image;
        //       model.thumbnailImage = uiImage;
        //     });
        //   });
        // });
      }
    }
  }

  @override
  Widget getContentAres(BuildContext context) {
    if(uiImage != null) {
      return SizedBox(
        width: uiImage!.width.toDouble(),
        height: uiImage!.height.toDouble(),
        child: Stack(
          children: [
            RawImage(image: uiImage,),
            Center(child: Image.asset("assets/images/video_msg_cover.png", width: 40, height: 40,),),
            Container(
              margin: EdgeInsets.fromLTRB(uiImage!.width.toDouble() - 30, uiImage!.height.toDouble() - 20, 8, 8),
              child: Text('${videoMessageContent.duration}s', style: const TextStyle(color: Colors.white),),
            )
          ],
        ),
      );
    } else {
      return const SizedBox(width: 48,height: 48,child: Center(child: CircularProgressIndicator(),),);
    }
  }
}
