import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import 'package:imclient/message/video_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:imclient/tools.dart';

import '../../ui_model/ui_message.dart';

class VideoCellBuilder extends PortraitCellBuilder {
  late VideoMessageContent videoMessageContent;
  Uint8List? thumbnail;

  // double _width;
  // double _height;

  VideoCellBuilder(BuildContext cell, UIMessage model) : super(cell, model) {
    videoMessageContent = model.message.content as VideoMessageContent;
    if (videoMessageContent.thumbnail != null) {
      if (videoMessageContent.thumbnail != null) {
        thumbnail = videoMessageContent.thumbnail;
      }
    }
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    // 获取缩略图的实际宽高
    int thumbWidth = 200;
    int thumbHeight = 200;
    if (thumbnail != null) {
      image.Image? img = image.decodeJpg(thumbnail!);
      if (img != null) {
        thumbWidth = img.width;
        thumbHeight = img.height;
      }
    }

    // 计算显示大小
    Size displaySize = Tools.getImageSizeByOrgSizeToWeChat(thumbWidth, thumbHeight);
    double width = displaySize.width > 0 ? displaySize.width : 200;
    double height = displaySize.height > 0 ? displaySize.height : 200;

    double dpr = MediaQuery.of(context).devicePixelRatio;

    // 优先检查本地视频文件
    if (videoMessageContent.localPath != null && videoMessageContent.localPath!.isNotEmpty) {
      File localFile = File(videoMessageContent.localPath!);
      if (localFile.existsSync()) {
        // 如果有本地文件，直接使用缩略图显示
        if (thumbnail != null) {
          return SizedBox(
            width: width / dpr,
            height: height / dpr,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Image.memory(
                    thumbnail!,
                    width: width,
                    height: height,
                    fit: BoxFit.cover,
                  ),
                  Center(child: Image.asset("assets/images/video_msg_cover.png", width: 40, height: 40,),),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text('${videoMessageContent.duration}s', style: const TextStyle(color: Colors.white, fontSize: 12),),
                    ),
                  )
                ],
              ),
            ),
          );
        }
      }
    }

    if (thumbnail != null) {
      return SizedBox(
        width: width / dpr,
        height: height / dpr,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Image.memory(
                thumbnail!,
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
              Center(
                child: Image.asset(
                  "assets/images/video_msg_cover.png",
                  width: 40,
                  height: 40,
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${videoMessageContent.duration}s',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              )
            ],
          ),
        ),
      );
    } else {
      return SizedBox(
        width: width / dpr,
        height: height / dpr,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${videoMessageContent.duration}s',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              )
            ],
          ),
        ),
      );
    }
  }
}
