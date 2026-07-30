import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
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

const imageContentMeta = MessageContentMeta(MESSAGE_CONTENT_TYPE_IMAGE,
    MessageFlag.PERSIST_AND_COUNT, ImageMessageContentCreator);

// 读取图片文件，解码并生成缩略图。
// 该方法为顶层函数，可通过 compute 放到后台 isolate 执行，避免阻塞主 isolate。
// 返回 {'w': 图片宽, 'h': 图片高, 'thumbnail': JPEG 缩略图字节(可能为空)}
Map<String, dynamic> _decodeImageAndGenThumbnail(String localPath) {
  int width = 0;
  int height = 0;
  Uint8List? thumbnail;

  // 从 localPath 读取图片，解析宽和高
  img.Image? originalImage;
  try {
    File file = File(localPath);
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

  // 生成缩略图
  if (originalImage != null && width > 0 && height > 0) {
    try {
      Size size = Tools.getImageSizeByOrgSizeToWeChat(width, height);

      img.Image thumbnailImg = img.copyResize(originalImage,
          width: size.width.toInt(),
          height: size.height.toInt(),
          interpolation: img.Interpolation.linear);
      thumbnail = img.encodeJpg(thumbnailImg, quality: 35);
    } catch (e) {
      // 缩略图生成失败
    }
  }

  return {'w': width, 'h': height, 'thumbnail': thumbnail};
}

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

  /// 发送前预处理：通过 compute 在后台 isolate 中读取/解码图片并生成缩略图，
  /// 避免 encode() 在主 isolate 同步执行文件 IO 和图片编解码导致 UI 卡顿。
  /// 预处理后 encode() 会直接使用已缓存的 width/height/thumbnail。
  Future<void> prepareEncode() async {
    // 与原 encode() 的触发条件保持一致：有本地路径且宽高未知时才解析
    if (localPath == null || localPath!.isEmpty || width != 0 || height != 0) {
      return;
    }
    Map<String, dynamic> result =
        await compute(_decodeImageAndGenThumbnail, localPath!);
    width = result['w'];
    height = result['h'];
    if (thumbnail == null && width > 0 && height > 0) {
      thumbnail = result['thumbnail'];
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = '[图片]';

    // 从 localPath 读取图片，解析宽和高。
    // 正常发送流程已在 prepareEncode() 中通过后台 isolate 完成预处理，
    // 此处仅作为未经过发送流程时的兜底逻辑
    if (localPath != null &&
        localPath!.isNotEmpty &&
        width == 0 &&
        height == 0) {
      Map<String, dynamic> result = _decodeImageAndGenThumbnail(localPath!);
      width = result['w'];
      height = result['h'];
      if (thumbnail == null && width > 0 && height > 0) {
        thumbnail = result['thumbnail'];
      }
    }

    if (thumbnail != null) {
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
