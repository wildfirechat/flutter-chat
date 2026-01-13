import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import 'package:imclient/message/video_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';

import '../message_cell.dart';
import '../../ui_model/ui_message.dart';

class VideoCellBuilder extends PortraitCellBuilder {
  late VideoMessageContent videoMessageContent;
  Uint8List? thumbnailData;

  VideoCellBuilder(BuildContext cell, UIMessage model) : super(cell, model) {
    videoMessageContent = model.message.content as VideoMessageContent;
    if(videoMessageContent.thumbnail != null) {
      if (videoMessageContent.thumbnail != null) {
        thumbnailData = Uint8List.fromList(image.encodeJpg(videoMessageContent.thumbnail!, quality: 70));
      }
    }
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    double width = 200;
    double height = 200;
    if(thumbnailData != null) {
      return SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            thumbnailData != null ?  Image.memory(
              thumbnailData!,
              width: width,
              height: height,
              fit: BoxFit.cover,
            ): const SizedBox(),
            Center(child: Image.asset("assets/images/video_msg_cover.png", width: 40, height: 40,),),
            Container(
              margin: EdgeInsets.fromLTRB(width - 30, height - 20, 8, 8),
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
