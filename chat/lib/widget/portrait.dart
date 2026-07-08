import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/media_url_redirector.dart';

class Portrait extends StatelessWidget {
  final String portrait;
  final String assetPlaceHolder;

  final double width;
  final double height;
  final double borderRadius;
  final GestureTapCallback? onTap;

  const Portrait(this.portrait, this.assetPlaceHolder, {super.key, this.width = 48.0, this.height = 48.0, this.borderRadius = 4.0, this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (portrait.isEmpty || portrait.startsWith('assets/')) {
      image = Image.asset(
        portrait.isEmpty ? assetPlaceHolder : portrait,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Image.asset(assetPlaceHolder, width: width, height: height),
      );
    } else {
      final redirectedUrl = MediaUrlRedirector.redirect(portrait);
      image = CachedNetworkImage(
        imageUrl: redirectedUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
        ),
        errorWidget: (context, url, err) => Image.asset(assetPlaceHolder, width: width, height: height),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image,
      ),
    );
  }
}
