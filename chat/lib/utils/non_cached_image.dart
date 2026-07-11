import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 加载图片并直接交给 [RawImage] 显示，不经过 Flutter 的 [ImageCache]。
///
/// 网络加载仍复用 [DefaultCacheManager] 磁盘缓存，因此与项目其他 [CachedNetworkImage]
/// 共享下载文件；本地文件则直接读取字节解码。大图预览场景使用本组件可避免把高分辨率
/// 解码图长期留在内存缓存中。
class NonCachedImage extends StatefulWidget {
  final Future<Uint8List> Function() loader;
  final Widget placeholder;
  final Widget errorWidget;
  final BoxFit? fit;
  final FilterQuality filterQuality;

  const NonCachedImage({
    super.key,
    required this.loader,
    required this.placeholder,
    required this.errorWidget,
    this.fit,
    this.filterQuality = FilterQuality.low,
  });

  /// 从网络加载，复用 [DefaultCacheManager] 磁盘缓存。
  factory NonCachedImage.network({
    Key? key,
    required String url,
    required Widget placeholder,
    required Widget errorWidget,
    BoxFit? fit,
    FilterQuality filterQuality = FilterQuality.low,
  }) {
    return NonCachedImage(
      key: key,
      loader: () async {
        final file = await DefaultCacheManager().getSingleFile(url);
        return file.readAsBytes();
      },
      placeholder: placeholder,
      errorWidget: errorWidget,
      fit: fit,
      filterQuality: filterQuality,
    );
  }

  /// 从本地文件路径加载。
  factory NonCachedImage.file({
    Key? key,
    required String path,
    required Widget placeholder,
    required Widget errorWidget,
    BoxFit? fit,
    FilterQuality filterQuality = FilterQuality.low,
  }) {
    return NonCachedImage(
      key: key,
      loader: () => File(path).readAsBytes(),
      placeholder: placeholder,
      errorWidget: errorWidget,
      fit: fit,
      filterQuality: filterQuality,
    );
  }

  @override
  State<NonCachedImage> createState() => _NonCachedImageState();
}

class _NonCachedImageState extends State<NonCachedImage> {
  ui.Image? _image;
  bool _loading = true;
  Object? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NonCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader) {
      _disposeImage();
      _load();
    }
  }

  @override
  void dispose() {
    _disposeImage();
    super.dispose();
  }

  void _disposeImage() {
    _image?.dispose();
    _image = null;
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await widget.loader();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _image?.dispose();
          _image = frame.image;
          _loading = false;
        });
      } else {
        frame.image.dispose();
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorWidget;
    }
    if (_loading || _image == null) {
      return widget.placeholder;
    }
    return RawImage(
      image: _image,
      fit: widget.fit,
      filterQuality: widget.filterQuality,
    );
  }
}
