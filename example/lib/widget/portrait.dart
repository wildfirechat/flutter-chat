import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

class Portrait extends StatelessWidget {
  final String portrait;
  final String assetPlaceHolder;

  final double width;
  final double height;
  final double borderRadius;
  final GestureTapCallback? onTap;

  const Portrait(this.portrait, this.assetPlaceHolder, {super.key, this.width = 40.0, this.height = 40.0, this.borderRadius = 4.0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: CachedNetworkImage(
            imageUrl: portrait,
            width: width,
            height: height,
            fit: BoxFit.cover,
            placeholder: (context, url) => Image.asset(assetPlaceHolder, width: width, height: height),
            errorWidget: (context, url, err) => Image.asset(assetPlaceHolder, width: width, height: height),
          )),
    );
  }
}
