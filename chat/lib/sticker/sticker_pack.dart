import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sticker_format.dart';

/// 一套贴纸,对应 assets/sticker/ 下的一个目录。
///
/// 目录里可以放 pack.json 描述这套贴纸(scripts/stickers/ 下的脚本生成):
/// ```json
/// {
///   "title": {"zh": "职场用语", "en": "Office Phrases"},
///   "order": 10,
///   "cover": "收到.tgs",
///   "stickers": ["收到.tgs", "好的.tgs"]
/// }
/// ```
/// order 越小越靠前;stickers 决定面板顺序,不在列表里的文件不显示。
/// 没有 pack.json 的旧目录:目录下所有贴纸按文件名排序,封面取
/// assets/sticker/<目录名>.<扩展名>,没有则取第一个贴纸。
/// 新增目录要在 pubspec.yaml 的 flutter.assets 里登记,否则不会打包。
class StickerPack {
  const StickerPack({
    required this.id,
    required this.titles,
    required this.order,
    required this.coverPath,
    required this.stickerPaths,
  });

  /// 目录名
  final String id;

  /// 语言代码 → 名称
  final Map<String, String> titles;
  final int order;
  final String coverPath;
  final List<String> stickerPaths;

  String titleFor(Locale locale) =>
      titles[locale.languageCode] ?? titles['zh'] ?? id;
}

class StickerPacks {
  StickerPacks._();

  static const String _root = 'assets/sticker/';
  static const String _manifestName = 'pack.json';

  /// 没写 order 的包排在内置包后面
  static const int _defaultOrder = 1000;

  static List<StickerPack> _loaded = const [];
  static Future<List<StickerPack>>? _loading;

  /// [load] 完成前为空列表。
  static List<StickerPack> get loaded => _loaded;

  static Future<List<StickerPack>> load() {
    return _loading ??=
        _load().then((packs) => _loaded = packs, onError: (Object error) {
      debugPrint('load sticker packs failed: $error');
      _loading = null;
      return _loaded;
    });
  }

  static Future<List<StickerPack>> _load() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().where((a) => a.startsWith(_root));

    final filesByPack = <String, List<String>>{};
    final legacyCovers = <String, String>{};
    for (final asset in assets) {
      final parts = asset.substring(_root.length).split('/');
      if (parts.length == 1) {
        final dot = parts[0].lastIndexOf('.');
        if (dot > 0) {
          legacyCovers[parts[0].substring(0, dot)] = asset;
        }
      } else if (parts.length == 2) {
        filesByPack.putIfAbsent(parts[0], () => []).add(parts[1]);
      }
    }

    final packs = <StickerPack>[];
    for (final MapEntry(key: id, value: files) in filesByPack.entries) {
      try {
        final pack = files.contains(_manifestName)
            ? await _fromManifest(id, files.toSet())
            : _fromDirectory(id, files, legacyCovers[id]);
        if (pack != null) {
          packs.add(pack);
        }
      } catch (e) {
        debugPrint('skip sticker pack $id: $e');
      }
    }
    packs.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });
    return packs;
  }

  static Future<StickerPack?> _fromManifest(
      String id, Set<String> files) async {
    final json =
        jsonDecode(await rootBundle.loadString('$_root$id/$_manifestName'))
            as Map<String, dynamic>;
    final stickers = <String>[];
    for (final name in (json['stickers'] as List).cast<String>()) {
      if (files.contains(name) && StickerFormat.fromPath(name) != null) {
        stickers.add('$_root$id/$name');
      } else {
        debugPrint('sticker pack $id: missing or unsupported $name');
      }
    }
    if (stickers.isEmpty) {
      return null;
    }
    final cover = json['cover'] as String?;
    return StickerPack(
      id: id,
      titles: (json['title'] as Map?)?.cast<String, String>() ?? const {},
      order: json['order'] as int? ?? _defaultOrder,
      coverPath: cover != null && files.contains(cover)
          ? '$_root$id/$cover'
          : stickers.first,
      stickerPaths: stickers,
    );
  }

  static StickerPack? _fromDirectory(
      String id, List<String> files, String? legacyCover) {
    final stickers = files
        .where((name) => StickerFormat.fromPath(name) != null)
        .map((name) => '$_root$id/$name')
        .toList()
      ..sort();
    if (stickers.isEmpty) {
      return null;
    }
    return StickerPack(
      id: id,
      titles: const {},
      order: _defaultOrder,
      coverPath: legacyCover ?? stickers.first,
      stickerPaths: stickers,
    );
  }
}
