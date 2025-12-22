import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class StickerCategory {
  final String name;
  final String coverPath; // The icon for the tab
  final List<String> stickerPaths;

  StickerCategory({required this.name, required this.coverPath, required this.stickerPaths});
}

class StickerManager {
  static final StickerManager _instance = StickerManager._internal();
  factory StickerManager() => _instance;
  StickerManager._internal();

  List<StickerCategory> _categories = [];
  List<StickerCategory> get categories => _categories;

  bool _isLoaded = false;

  Future<void> loadStickers() async {
    if (_isLoaded) return;

    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      final stickerAssets = manifestMap.keys
          .where((String key) => key.startsWith('assets/sticker/'))
          .toList();

      // Group by directory
      final Map<String, List<String>> directoryMap = {};
      final Map<String, String> categoryCovers = {};

      for (final path in stickerAssets) {
        final parts = path.split('/');
        
        if (parts.length == 3) {
          // It's a file in assets/sticker root, likely a cover
          final fileName = parts[2];
          if (fileName.contains('.')) {
             final nameWithoutExt = fileName.split('.').first;
             categoryCovers[nameWithoutExt] = path;
          }
        } else if (parts.length == 4) {
          // It's a sticker inside a category folder
          final categoryName = parts[2];
          directoryMap.putIfAbsent(categoryName, () => []).add(path);
        }
      }

      _categories = directoryMap.entries.map((entry) {
        final name = entry.key;
        final paths = entry.value;
        return StickerCategory(
          name: name,
          coverPath: categoryCovers[name] ?? paths.first,
          stickerPaths: paths,
        );
      }).toList();

      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading stickers: $e');
    }
  }
}
