import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'media_url_redirector.dart';

/// 支持双网 URL 前缀转换的 [ImageProvider]。
class RedirectNetworkImage extends ImageProvider<RedirectNetworkImage> {
  final String url;
  final double scale;

  const RedirectNetworkImage(this.url, {this.scale = 1.0});

  @override
  Future<RedirectNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<RedirectNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    RedirectNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    final provider = CachedNetworkImageProvider(
      MediaUrlRedirector.redirect(key.url),
      scale: key.scale,
    );
    return provider.loadImage(provider, decode);
  }

  @override
  bool operator ==(Object other) =>
      other is RedirectNetworkImage &&
      other.url == url &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);
}
