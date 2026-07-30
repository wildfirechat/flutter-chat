import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:imclient/message/image_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:chat/conversation/media_cell_anchor.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:imclient/tools.dart';

import '../../ui_model/ui_message.dart';

class ImageCellBuilder extends PortraitCellBuilder {
  late ImageMessageContent imageMessageContent;
  Uint8List? thumbnail;

  // 本地文件存在性在构造时判断一次，避免每次 build 都在主 isolate 同步 stat
  bool _localFileExists = false;

  ImageCellBuilder(BuildContext context, UIMessage model)
      : super(context, model) {
    imageMessageContent = model.message.content as ImageMessageContent;
    if (imageMessageContent.thumbnail != null) {
      thumbnail = imageMessageContent.thumbnail!;
    }
    if (imageMessageContent.localPath != null &&
        imageMessageContent.localPath!.isNotEmpty) {
      _localFileExists = File(imageMessageContent.localPath!).existsSync();
    }
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    // 锚点登记缩略图位置,预览拖拽退出时大图缩回到这里
    return MediaCellAnchor(
      messageId: model.message.messageId,
      child: _buildThumbnail(context),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    Size imageSize = Tools.getImageSizeByOrgSizeToWeChat(
        imageMessageContent.width, imageMessageContent.height);
    double width = imageSize.width > 0 ? imageSize.width : 200;
    double height = imageSize.height > 0 ? imageSize.height : 200;

    double dpr = MediaQuery.of(context).devicePixelRatio;

    // 优先检查本地文件(存在性已在构造时缓存)
    if (_localFileExists) {
      File localFile = File(imageMessageContent.localPath!);
      return SizedBox(
        width: width / dpr,
        height: height / dpr,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            localFile,
            width: width,
            height: height,
            // 按显示尺寸×dpr 解码，避免原图全尺寸解码占用大量内存
            cacheWidth: (width * dpr).ceil(),
            cacheHeight: (height * dpr).ceil(),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // 如果有原图 URL，使用 CachedNetworkImage 加载并缓存
    if (imageMessageContent.remoteUrl != null) {
      return SizedBox(
        width: width / dpr,
        height: height / dpr,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl:
                MediaUrlRedirector.redirect(imageMessageContent.remoteUrl!),
            width: width,
            height: height,
            memCacheWidth: (width * dpr).ceil(),
            memCacheHeight: (height * dpr).ceil(),
            fit: BoxFit.cover,
            placeholder: (context, url) {
              // 加载中显示缩略图或占位符
              if (thumbnail != null) {
                return Image.memory(
                  thumbnail!,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                );
              } else {
                return Container(
                  color: Colors.grey[300],
                );
              }
            },
            errorWidget: (context, url, error) {
              // 加载失败显示缩略图或错误占位符
              if (thumbnail != null) {
                return Image.memory(
                  thumbnail!,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                );
              } else {
                return Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.error, color: Colors.grey[600]),
                );
              }
            },
          ),
        ),
      );
    } else if (thumbnail != null) {
      // 只有缩略图，没有原图
      return SizedBox(
        width: width / dpr,
        height: height / dpr,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            thumbnail!,
            width: width,
            height: height,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      // 没有缩略图也没有原图，显示占位符
      return SizedBox(
        width: width / dpr,
        height: height / dpr,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Colors.grey[300],
          ),
        ),
      );
    }
  }
}
