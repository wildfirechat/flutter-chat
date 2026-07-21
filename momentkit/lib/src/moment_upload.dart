import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:imclient/imclient.dart';
import 'package:imclient/message/message_content.dart';
import 'package:momentclient/momentclient.dart';

import 'moment_media_picker.dart';

/// 媒体上传辅助。
///
/// 统一走 [Imclient.uploadMediaFile] / [Imclient.uploadMedia]，图片会额外生成
/// 缩略图（最长边 400px，PNG）并上传，作为九宫格/消息列表里的缩略展示。
class MomentUploader {
  MomentUploader._();

  static const int _thumbMaxSide = 400;

  /// 上传单个文件并返回远端 URL。
  static Future<String> uploadFile(String path, MediaType type) {
    final completer = Completer<String>();
    Imclient.uploadMediaFile(path, type, (remoteUrl) {
      completer.complete(remoteUrl);
    }, (current, total) {}, (errorCode) {
      completer.completeError(Exception('upload failed: $errorCode'));
    });
    return completer.future;
  }

  /// 上传内存数据并返回远端 URL。
  static Future<String> uploadBytes(
      String fileName, Uint8List bytes, MediaType type) {
    final completer = Completer<String>();
    Imclient.uploadMedia(fileName, bytes, type, (remoteUrl) {
      completer.complete(remoteUrl);
    }, (current, total) {}, (errorCode) {
      completer.completeError(Exception('upload failed: $errorCode'));
    });
    return completer.future;
  }

  /// 上传一张图片并生成 [FeedEntry]（含原图 URL、缩略图 URL、宽高）。
  static Future<FeedEntry> uploadImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;

    // 缩略图：等比缩放到最长边 _thumbMaxSide。
    ui.Image? thumbImage;
    if (width > _thumbMaxSide || height > _thumbMaxSide) {
      final scale = _thumbMaxSide / (width > height ? width : height);
      final tw = (width * scale).round();
      final th = (height * scale).round();
      final thumbCodec = await ui.instantiateImageCodec(bytes,
          targetWidth: tw, targetHeight: th);
      final thumbFrame = await thumbCodec.getNextFrame();
      thumbImage = thumbFrame.image;
    } else {
      thumbImage = image;
    }
    final byteData =
        await thumbImage.toByteData(format: ui.ImageByteFormat.png);
    final thumbBytes = byteData!.buffer.asUint8List();

    final mediaUrl = await uploadFile(path, MediaType.Media_Type_IMAGE);
    final thumbUrl = await uploadBytes(
        'thumb_${DateTime.now().millisecondsSinceEpoch}.png',
        thumbBytes,
        MediaType.Media_Type_IMAGE);

    image.dispose();
    if (!identical(thumbImage, image)) thumbImage.dispose();

    final entry = FeedEntry();
    entry.mediaUrl = mediaUrl;
    entry.thumbUrl = thumbUrl;
    entry.mediaWidth = width;
    entry.mediaHeight = height;
    return entry;
  }

  /// 上传一个视频并生成 [FeedEntry]（无缩略图，九宫格显示播放占位）。
  static Future<FeedEntry> uploadVideo(String path) async {
    final mediaUrl = await uploadFile(path, MediaType.Media_Type_VIDEO);
    final entry = FeedEntry();
    entry.mediaUrl = mediaUrl;
    return entry;
  }
}

/// 上传单个媒体文件并返回远端 URL（背景图等不需要 [FeedEntry] 的场景）。
Future<String> uploadMomentMedia(MomentPickedMedia media) {
  return MomentUploader.uploadFile(
      media.path,
      media.isVideo ? MediaType.Media_Type_VIDEO : MediaType.Media_Type_IMAGE);
}
