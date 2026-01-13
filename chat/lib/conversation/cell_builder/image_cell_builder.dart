import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat/utilities.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import 'package:imclient/message/image_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';

import '../../ui_model/ui_message.dart';

class ImageCellBuilder extends PortraitCellBuilder {
  late ImageMessageContent imageMessageContent;
  Uint8List? thumbnailData;

  ImageCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    imageMessageContent = model.message.content as ImageMessageContent;
    if (imageMessageContent.thumbnail != null) {
      thumbnailData = Uint8List.fromList(image.encodeJpg(imageMessageContent.thumbnail!, quality: 70));
    }
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    Size imageSize = Utilities.getImageSizeByOrgSizeToWeChat(imageMessageContent.width, imageMessageContent.height);
    double width = imageSize.width > 0 ? imageSize.width : 200;
    double height = imageSize.height > 0 ? imageSize.height : 200;

    double dpr = MediaQuery.of(context).devicePixelRatio;

    // 如果有原图 URL，使用 CachedNetworkImage 加载并缓存
    if (imageMessageContent.remoteUrl != null) {
      return SizedBox(
        width: width / dpr,
        height: height / dpr,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageMessageContent.remoteUrl!,
            width: width,
            height: height,
            fit: BoxFit.cover,
            placeholder: (context, url) {
              // 加载中显示缩略图或占位符
              if (thumbnailData != null) {
                return Image.memory(
                  thumbnailData!,
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
              if (thumbnailData != null) {
                return Image.memory(
                  thumbnailData!,
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
    } else if (thumbnailData != null) {
      // 只有缩略图，没有原图
      return SizedBox(
        width: width / dpr,
        height: height / dpr,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            thumbnailData!,
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
