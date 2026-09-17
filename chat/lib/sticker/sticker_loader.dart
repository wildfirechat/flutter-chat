import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lottie/lottie.dart';

import 'package:chat/utils/media_url_redirector.dart';
import 'sticker_format.dart';
import 'sticker_source.dart';

/// 解析完成、可以直接渲染的贴纸:二者恰有一个非空。
class LoadedSticker {
  const LoadedSticker.image(ImageProvider image) : this._(image: image);

  const LoadedSticker.lottie(LottieComposition composition)
      : this._(composition: composition);

  const LoadedSticker._({this.image, this.composition});

  /// 未缩放的原始图片;显示时由调用方按尺寸套 [ResizeImage]。
  final ImageProvider? image;

  final LottieComposition? composition;
}

/// 贴纸加载:识别格式、下载远端文件、解析 Lottie,并做内存缓存。
///
/// 解析结果按 [StickerSource] 缓存,聊天列表滚动回来、面板翻页回来都能同步拿到
/// ([peek]),不会闪一下占位。Lottie 解析(单个 2~16ms)放到后台 isolate,并限制
/// 并发,打开一页几十个贴纸时主线程不卡、也不会同时拉起几十个 isolate。
class StickerLoader {
  StickerLoader._();

  /// 缓存条数上限。一个 Lottie 解析后常驻内存约几百 KB,图片贴纸只存 provider。
  static const int _capacity = 100;
  static const int _maxParallelDecodes = 2;

  static final LinkedHashMap<StickerSource, LoadedSticker> _cache =
      LinkedHashMap();
  static final Map<StickerSource, Future<LoadedSticker>> _pending = {};

  static int _activeDecodes = 0;
  static final Queue<Completer<void>> _decodeWaiters = Queue();

  /// 已缓存的结果,没有返回 null。命中时刷新 LRU 顺序。
  static LoadedSticker? peek(StickerSource source) {
    final hit = _cache.remove(source);
    if (hit != null) {
      _cache[source] = hit;
    }
    return hit;
  }

  static Future<LoadedSticker> load(StickerSource source) {
    final hit = peek(source);
    if (hit != null) {
      return SynchronousFuture(hit);
    }
    // 注意不能写 whenComplete(() => _pending.remove(source)):remove 返回的正是
    // 这个 Future 本身,whenComplete 会等回调返回的 Future,自己等自己,永远不完成
    return _pending[source] ??= _load(source).then((loaded) {
      _pending.remove(source);
      _cache[source] = loaded;
      if (_cache.length > _capacity) {
        _cache.remove(_cache.keys.first);
      }
      return loaded;
    }, onError: (Object error, StackTrace stackTrace) {
      // 失败不缓存,下次挂载重试
      _pending.remove(source);
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  static Future<LoadedSticker> _load(StickerSource source) async {
    switch (source) {
      case AssetStickerSource(:final path):
        final format = StickerFormat.fromPath(path) ?? StickerFormat.image;
        if (format == StickerFormat.image) {
          return LoadedSticker.image(AssetImage(path));
        }
        final data = await rootBundle.load(path);
        return LoadedSticker.lottie(await _decodeLottie(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)));
      case FileStickerSource(:final path):
        return _loadFile(File(path));
      case NetworkStickerSource(:final url):
        // 缓存 key 用原始地址:主备网切换后前缀变了,也能命中同一份磁盘缓存
        final file = await DefaultCacheManager()
            .getSingleFile(MediaUrlRedirector.redirect(url), key: url);
        return _loadFile(file);
    }
  }

  /// 本地文件一律看文件头:下载缓存文件的扩展名取自 Content-Type,不可靠。
  static Future<LoadedSticker> _loadFile(File file) async {
    final raf = await file.open();
    final Uint8List head;
    try {
      head = await raf.read(8);
    } finally {
      await raf.close();
    }
    if (StickerFormat.sniff(head) == StickerFormat.image) {
      return LoadedSticker.image(FileImage(file));
    }
    return LoadedSticker.lottie(await _decodeLottie(await file.readAsBytes()));
  }

  static Future<LottieComposition> _decodeLottie(Uint8List bytes) async {
    if (_activeDecodes < _maxParallelDecodes) {
      _activeDecodes++;
    } else {
      final waiter = Completer<void>();
      _decodeWaiters.add(waiter);
      // 名额由结束的任务直接移交过来,不再自增
      await waiter.future;
    }
    try {
      // gzip(.tgs)与纯 JSON 都认:decodeGZip 不是 gzip 时返回 null,回落到 JSON 解析
      return await Isolate.run(() => LottieComposition.fromBytes(bytes,
          decoder: LottieComposition.decodeGZip));
    } finally {
      if (_decodeWaiters.isNotEmpty) {
        _decodeWaiters.removeFirst().complete();
      } else {
        _activeDecodes--;
      }
    }
  }
}
