import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import 'package:imclient/message/video_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:chat/conversation/media_cell_anchor.dart';
import 'package:chat/utils/duration_formatter.dart';
import 'package:imclient/tools.dart';

import '../../ui_model/ui_message.dart';
import 'package:chat/theme/app_typography.dart';

class VideoCellBuilder extends PortraitCellBuilder {
  late VideoMessageContent videoMessageContent;
  Uint8List? thumbnail;

  // double _width;
  // double _height;

  // 缩略图宽高与本地文件存在性在构造时计算一次，避免每次 build 都在主 isolate 解码 JPEG / 同步 stat
  int _thumbWidth = 200;
  int _thumbHeight = 200;
  bool _localFileExists = false;

  VideoCellBuilder(BuildContext cell, UIMessage model) : super(cell, model) {
    videoMessageContent = model.message.content as VideoMessageContent;
    if (videoMessageContent.thumbnail != null) {
      thumbnail = videoMessageContent.thumbnail;
      image.Image? img = image.decodeJpg(thumbnail!);
      if (img != null) {
        _thumbWidth = img.width;
        _thumbHeight = img.height;
      }
    }
    if (videoMessageContent.localPath != null && videoMessageContent.localPath!.isNotEmpty) {
      _localFileExists = File(videoMessageContent.localPath!).existsSync();
    }
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    // 锚点登记缩略图位置,预览拖拽退出时缩回到这里
    return MediaCellAnchor(
      messageId: model.message.messageId,
      child: _buildThumbnail(context),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    // 缩略图宽高已在构造时解码并缓存，直接使用
    // 计算显示大小
    Size displaySize = Tools.getImageSizeByOrgSizeToWeChat(_thumbWidth, _thumbHeight);
    double width = displaySize.width > 0 ? displaySize.width : 200;
    double height = displaySize.height > 0 ? displaySize.height : 200;

    double dpr = MediaQuery.of(context).devicePixelRatio;

    // 优先检查本地视频文件(存在性已在构造时缓存)
    if (_localFileExists) {
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
                      child: Text(formatMediaDuration(videoMessageContent.duration), style: AppText.xs.copyWith(color: Colors.white),),
                    ),
                  )
                ],
              ),
            ),
          );
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
                    formatMediaDuration(videoMessageContent.duration),
                    style: AppText.xs.copyWith(color: Colors.white),
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
                    formatMediaDuration(videoMessageContent.duration),
                    style: AppText.xs.copyWith(color: Colors.white),
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
