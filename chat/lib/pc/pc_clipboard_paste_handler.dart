import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';

import 'package:chat/conversation/input_bar/message_input_bar_controller.dart';

/// PC 输入框粘贴处理:优先文件路径,再图片数据,最后回退纯文本。
class PcClipboardPasteHandler {
  const PcClipboardPasteHandler();

  static const List<SimpleFileFormat> _clipboardImageFormats = [
    // 优先可直接显示的常见格式;避免先命中 tiff/heic 导致粘贴后无法渲染
    Formats.png,
    Formats.jpeg,
    Formats.gif,
    Formats.webp,
    Formats.bmp,
    Formats.tiff,
    Formats.heic,
    Formats.heif,
    Formats.ico,
  ];

  static const Set<String> _inlineImageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
  };

  Future<void> handlePaste(
    MessageInputBarController controller, {
    required bool Function() isMounted,
  }) async {
    try {
      final clipboard = SystemClipboard.instance;
      final reader = clipboard == null ? null : await clipboard.read();
      // 文件路径优先于图片数据:复制的图片文件也带合成的图片数据格式,
      // 走文件路径可直接用原文件,免去重新编码/落临时文件
      if (reader != null &&
          await _tryPasteFiles(reader, controller, isMounted: isMounted)) {
        return;
      }
      if (reader == null) {
        await _pasteTextFallback(controller);
        return;
      }
      final normalized = await _readClipboardImageForPaste(reader);
      if (normalized == null || normalized.bytes.isEmpty) {
        if (await _tryPasteHtmlImage(reader, controller,
            isMounted: isMounted)) {
          return;
        }
        // 图片读取失败时回退到文本粘贴,避免 Ctrl/Cmd+V 被吞掉后无反馈。
        await _pasteTextFallback(controller);
        return;
      }
      if (!isMounted()) {
        return;
      }
      final path =
          await _writeTempImage(normalized.bytes, normalized.extension);
      if (!isMounted()) {
        return;
      }
      controller.insertInlineImage(path);
    } catch (e) {
      debugPrint('paste image failed: $e');
    }
  }

  Future<void> _pasteTextFallback(MessageInputBarController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      controller.insertText(text);
    }
  }

  Future<String> _writeTempImage(List<int> bytes, String extension) async {
    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/paste_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<_NormalizedImage?> _readClipboardImageForPaste(
      ClipboardReader reader) async {
    final availableFormats = <SimpleFileFormat>[];
    for (final format in _clipboardImageFormats) {
      if (reader.canProvide(format)) {
        availableFormats.add(format);
      }
    }
    if (availableFormats.isEmpty) {
      return null;
    }
    for (final format in availableFormats) {
      try {
        final bytes = await _readClipboardImage(reader, format);
        if (bytes == null || bytes.isEmpty) {
          continue;
        }
        final normalized = _normalizeClipboardImageBytes(format, bytes);
        if (normalized != null && normalized.bytes.isNotEmpty) {
          return normalized;
        }
      } catch (e) {
        debugPrint('paste image read failed for $format: $e');
      }
    }
    debugPrint(
        'paste image failed, available formats: ${availableFormats.join(', ')}');
    return null;
  }

  Future<List<int>?> _readClipboardImage(
      ClipboardReader reader, SimpleFileFormat format) async {
    final completer = Completer<List<int>?>();
    final progress = reader.getFile(
      format,
      (file) async {
        try {
          final bytes = await file.readAll();
          if (!completer.isCompleted) {
            completer.complete(bytes);
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );
    if (progress == null) {
      return null;
    }
    return completer.future
        .timeout(const Duration(seconds: 2), onTimeout: () => null);
  }

  _NormalizedImage? _normalizeClipboardImageBytes(
      SimpleFileFormat format, List<int> bytes) {
    if (format == Formats.png) return _NormalizedImage(bytes, 'png');
    if (format == Formats.jpeg) return _NormalizedImage(bytes, 'jpg');
    if (format == Formats.gif) return _NormalizedImage(bytes, 'gif');
    if (format == Formats.webp) return _NormalizedImage(bytes, 'webp');
    if (format == Formats.bmp) return _NormalizedImage(bytes, 'bmp');

    // tiff/heic/heif/ico 等在 Flutter Image.file 里兼容性差,统一转成 png 再插入
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) {
      debugPrint('paste image decode failed for format: $format');
      return null;
    }
    return _NormalizedImage(img.encodePng(decoded), 'png');
  }

  Future<bool> _tryPasteHtmlImage(
    ClipboardReader reader,
    MessageInputBarController controller, {
    required bool Function() isMounted,
  }) async {
    if (!reader.canProvide(Formats.htmlText)) {
      return false;
    }
    final html = await reader.readValue(Formats.htmlText);
    if (html == null || html.isEmpty) {
      return false;
    }

    final fileSrcPattern =
        RegExp("src=[\"'](file:[^\"']+)[\"']", caseSensitive: false);
    for (final match in fileSrcPattern.allMatches(html)) {
      final raw = match.group(1);
      if (raw == null || raw.isEmpty) continue;
      try {
        final path = _safeFileUriToPath(Uri.parse(raw));
        if (path == null || path.isEmpty) continue;
        final file = File(path);
        if (!await file.exists()) continue;
        controller.insertInlineImage(path);
        return true;
      } catch (_) {
        // ignore malformed uri and continue probing
      }
    }

    final dataSrcPattern =
        RegExp("src=[\"'](data:image/[^\"']+)[\"']", caseSensitive: false);
    final dataMatch = dataSrcPattern.firstMatch(html);
    final dataSrc = dataMatch?.group(1);
    if (dataSrc == null || dataSrc.isEmpty) {
      return false;
    }
    try {
      final uriData = UriData.parse(dataSrc);
      final bytes = uriData.contentAsBytes();
      if (bytes.isEmpty) {
        return false;
      }
      final ext = _extensionFromMime(uriData.mimeType);
      final path = await _writeTempImage(bytes, ext);
      if (!isMounted()) {
        return false;
      }
      controller.insertInlineImage(path);
      return true;
    } catch (e) {
      debugPrint('paste html image decode failed: $e');
      return false;
    }
  }

  String _extensionFromMime(String? mimeType) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.endsWith('/png')) return 'png';
    if (mime.endsWith('/gif')) return 'gif';
    if (mime.endsWith('/webp')) return 'webp';
    if (mime.endsWith('/bmp')) return 'bmp';
    if (mime.endsWith('/tiff')) return 'tiff';
    if (mime.endsWith('/heic')) return 'heic';
    if (mime.endsWith('/heif')) return 'heif';
    return 'jpg';
  }

  String? _safeFileUriToPath(Uri uri) {
    if (uri.scheme != 'file') {
      return null;
    }
    // macOS/Linux 上 file://localhost/... 常见于外部应用剪贴板,需手动兼容 authority。
    if (!Platform.isWindows &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        uri.host != 'localhost') {
      return null;
    }
    try {
      return uri.toFilePath(windows: Platform.isWindows);
    } catch (_) {
      if (!Platform.isWindows && uri.host == 'localhost') {
        try {
          return Uri(scheme: 'file', path: uri.path).toFilePath();
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }

  /// 剪贴板携带文件路径时按条目顺序逐个内联插入,返回是否插入了内容。
  /// 图片文件内联显示原图,其他文件显示为文件卡片;
  /// 文件夹和已失效的路径跳过(与微信 PC 一致,不支持粘贴文件夹)。
  Future<bool> _tryPasteFiles(
    ClipboardReader reader,
    MessageInputBarController controller, {
    required bool Function() isMounted,
  }) async {
    if (!reader.canProvide(Formats.fileUri)) {
      return false;
    }
    // 先按剪贴板条目顺序读全所有路径,再统一插入,保证多选文件的粘贴顺序稳定
    final List<String> paths = [];
    for (final item in reader.items) {
      if (!item.canProvide(Formats.fileUri)) continue;
      final uri = await item.readValue(Formats.fileUri);
      if (uri == null) continue;
      final path = _safeFileUriToPath(uri);
      if (path != null && path.isNotEmpty) {
        paths.add(path);
      }
    }
    bool inserted = false;
    for (final path in paths) {
      final file = File(path);
      // File.exists 对文件夹返回 false,顺带滤掉文件夹
      if (!await file.exists()) continue;
      final int size = await file.length();
      if (!isMounted()) break;
      if (_isImageFile(path)) {
        controller.insertInlineImage(path);
      } else {
        controller.insertInlineFile(path, p.basename(path), size);
      }
      inserted = true;
    }
    return inserted;
  }

  bool _isImageFile(String path) =>
      _inlineImageExtensions.contains(p.extension(path).toLowerCase());
}

class _NormalizedImage {
  const _NormalizedImage(this.bytes, this.extension);

  final List<int> bytes;
  final String extension;
}
