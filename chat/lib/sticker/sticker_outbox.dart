import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:imclient/message/sticker_message_content.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sticker_format.dart';
import 'sticker_loader.dart';
import 'sticker_source.dart';

/// 准备好的贴纸消息。
class OutgoingSticker {
  const OutgoingSticker._(this.content, this._contentHash);

  final StickerMessageContent content;
  final String _contentHash;

  /// 没有可复用的远端地址,需走 sendMediaMessage 由 SDK 上传 [StickerMessageContent.localPath]。
  bool get needsUpload => content.remoteUrl?.isNotEmpty != true;

  /// 上传完成回调里调用,下次发同一个贴纸直接复用远端地址。
  void rememberRemoteUrl(String remoteUrl) =>
      StickerOutbox._rememberUpload(_contentHash, remoteUrl);
}

/// 把面板里的内置贴纸(asset)做成贴纸消息。
///
/// SDK 只能上传文件:首次发送把 asset 写到临时目录交给 SDK 上传,上传完成记下远端地址,
/// 之后再发同一个贴纸直接带远端地址,不重复上传。远端地址按文件内容哈希缓存,
/// 贴纸包重新生成(内容变了)后不会误发旧文件。
class StickerOutbox {
  StickerOutbox._();

  static const String _uploadsKey = 'wfc_sticker_uploads';

  /// 旧版按 asset 路径缓存远端地址,内容变了会误发旧文件,已弃用
  static const String _legacyUploadsKey = 'wfc_sticker_remote_urls';

  static Future<Map<String, String>>? _uploads;
  static final Map<String, Future<_StickerFile>> _files = {};

  static Future<OutgoingSticker> prepare(String assetPath) async {
    final file = await _materialize(assetPath);
    final uploads = await (_uploads ??= _loadUploads());

    final content = StickerMessageContent()
      ..width = file.width
      ..height = file.height
      // 本地文件也带上:自己这条消息直接读本地,不用再下载一遍
      ..localPath = file.path;
    final remoteUrl = uploads[file.hash];
    if (remoteUrl != null) {
      content.remoteUrl = remoteUrl;
    }
    return OutgoingSticker._(content, file.hash);
  }

  static Future<_StickerFile> _materialize(String assetPath) async {
    final pending = _files[assetPath] ??= _writeFile(assetPath);
    try {
      final file = await pending;
      // 临时目录可能被系统清理
      if (await File(file.path).exists()) {
        return file;
      }
    } catch (_) {
      // 失败的结果不缓存,下次重试
    }
    _files.remove(assetPath);
    return _files[assetPath] = _writeFile(assetPath);
  }

  static Future<_StickerFile> _writeFile(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final hash = md5.convert(bytes).toString();

    // 按内容哈希命名:不同贴纸包里的同名文件不会互相覆盖
    final dot = assetPath.lastIndexOf('.');
    final ext = dot >= 0 ? assetPath.substring(dot).toLowerCase() : '';
    final dir = Directory('${(await getTemporaryDirectory()).path}/stickers');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$hash$ext');
    if (!await file.exists() || await file.length() != bytes.length) {
      await file.writeAsBytes(bytes, flush: true);
    }

    final ui.Size size;
    if (StickerFormat.fromPath(assetPath) == StickerFormat.lottie) {
      final bounds = (await StickerLoader.load(StickerSource.asset(assetPath)))
          .composition!
          .bounds;
      size = ui.Size(bounds.width.toDouble(), bounds.height.toDouble());
    } else {
      size = await _imageSize(bytes);
    }
    return _StickerFile(
        file.path, hash, size.width.round(), size.height.round());
  }

  /// 只解析图片头拿宽高,不解码像素
  static Future<ui.Size> _imageSize(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size =
          ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
      descriptor.dispose();
      return size;
    } finally {
      buffer.dispose();
    }
  }

  static Future<Map<String, String>> _loadUploads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.remove(_legacyUploadsKey);
      final json = prefs.getString(_uploadsKey);
      if (json != null) {
        return (jsonDecode(json) as Map).cast<String, String>();
      }
    } catch (e) {
      debugPrint('load sticker uploads failed: $e');
    }
    return {};
  }

  static Future<void> _rememberUpload(String hash, String remoteUrl) async {
    final uploads = await (_uploads ??= _loadUploads());
    uploads[hash] = remoteUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_uploadsKey, jsonEncode(uploads));
    } catch (e) {
      debugPrint('save sticker upload failed: $e');
    }
  }
}

class _StickerFile {
  const _StickerFile(this.path, this.hash, this.width, this.height);

  final String path;
  final String hash;
  final int width;
  final int height;
}
