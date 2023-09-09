import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import 'package:flutter/cupertino.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:wfc_example/messages/cell_builder/portrait_cell_builder.dart';

import '../message_cell.dart';
import '../message_model.dart';

class VideoCellBuilder extends PortraitCellBuilder {
  late VideoMessageContent videoMessageContent;
  ui.Image? uiImage;

  VideoCellBuilder(MessageState state, MessageModel model) : super(state, model) {
    videoMessageContent = model.message.content as VideoMessageContent;
    if(videoMessageContent.thumbnail != null) {
      ui.instantiateImageCodec(image.encodePng(videoMessageContent.thumbnail!))
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
