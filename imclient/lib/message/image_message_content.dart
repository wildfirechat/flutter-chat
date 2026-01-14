import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;

import '../model/message_payload.dart';
import '../tools.dart';
import 'media_message_content.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent ImageMessageContentCreator() {
  return ImageMessageContent();
}

const imageContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_IMAGE, MessageFlag.PERSIST_AND_COUNT, ImageMessageContentCreator);

class ImageMessageContent extends MediaMessageContent {
  Uint8List? thumbnail;
  int width = 0;
  int height = 0;

  @override
  MessageContentMeta get meta => imageContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    thumbnail = payload.binaryContent;

    if (payload.content != null) {
      try {
        Map<String, dynamic> json = jsonDecode(payload.content!);
        width = json['w'] ?? 0;
        height = json['h'] ?? 0;
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = '[图片]';

    // 从 localPath 读取图片，解析宽和高
    img.Image? originalImage;
    if (localPath != null && localPath!.isNotEmpty && width == 0 && height == 0) {
      try {
        File file = File(localPath!);
        if (file.existsSync()) {
          originalImage = img.decodeImage(file.readAsBytesSync());
          if (originalImage != null) {
            width = originalImage.width;
            height = originalImage.height;
          }
        }
      } catch (e) {
        // 解析失败，继续使用已有的 width 和 height
      }
    }

    // 生成缩略图
    if (thumbnail == null && originalImage != null && width > 0 && height > 0) {
      try {
        Size size = Tools.getImageSizeByOrgSizeToWeChat(width, height);

        img.Image thumbnailImg = img.copyResize(originalImage,
          width: size.width.toInt(),
          height: size.height.toInt(),
          interpolation: img.Interpolation.linear
        );
        payload.binaryContent = img.encodeJpg(thumbnailImg!, quality: 35);
      } catch (e) {
        // 缩略图生成失败
      }
    } else if (thumbnail != null) {
      payload.binaryContent = thumbnail;
    }

    // 将宽和高编码到 JSON 内容中
    Map<String, dynamic> json = {
      'w': width,
      'h': height,
    };
    payload.content = jsonEncode(json);

    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[图片]';
  }

  @override
  MediaType get mediaType => MediaType.Media_Type_IMAGE;
}
