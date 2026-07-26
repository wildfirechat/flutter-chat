import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../moment_user_cache.dart';

/// 朋友圈昵称颜色（微信蓝）。
const Color kMomentNameColor = Color(0xFF576B95);

/// 朋友圈评论/点赞区背景色。
const Color kMomentCommentBg = Color(0xFFF3F3F5);

/// 用户头像（自动走 [MomentUserCache]，头像为空时用灰底人形占位）。
class MomentAvatar extends StatelessWidget {
  final String userId;
  final double size;
  final double borderRadius;
  final VoidCallback? onTap;

  const MomentAvatar(
    this.userId, {
    super.key,
    this.size = 42,
    this.borderRadius = 4,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: size,
          height: size,
          // 只订阅当前用户的变更,其他用户加载完成不会触发本头像重建
          child: ValueListenableBuilder<int>(
            valueListenable: MomentUserCache.instance.notifierOf(userId),
            builder: (context, _, __) {
              final url = MomentUserCache.instance.portraitOf(userId);
              if (url.isEmpty) return _placeholder();
              // 按显示尺寸×DPR 限制解码大小，避免原图占满内存缓存
              final cacheSize =
                  (size * MediaQuery.devicePixelRatioOf(context)).round();
              return CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                memCacheWidth: cacheSize,
                memCacheHeight: cacheSize,
                placeholder: (context, _) => _placeholder(),
                errorWidget: (context, _, __) => _placeholder(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFD8D8D8),
      child: Icon(Icons.person, size: size * 0.7, color: Colors.white),
    );
  }
}

/// 用户名文本（自动走 [MomentUserCache]，默认微信蓝）。
class MomentUserName extends StatelessWidget {
  final String userId;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final VoidCallback? onTap;
  final int maxLines;

  const MomentUserName(
    this.userId, {
    super.key,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w500,
    this.color = kMomentNameColor,
    this.onTap,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // 只订阅当前用户的变更,其他用户加载完成不会触发本文本重建
      child: ValueListenableBuilder<int>(
        valueListenable: MomentUserCache.instance.notifierOf(userId),
        builder: (context, _, __) {
          return Text(
            MomentUserCache.instance.displayNameOf(userId),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          );
        },
      ),
    );
  }
}

/// 网络图片（带灰底占位与失败兜底）。
class MomentNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// 内存缓存解码宽度（px），不传则按原图解码；大图建议传入显示宽度×DPR。
  final int? memCacheWidth;

  const MomentNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    Widget ph() => Container(
          width: width,
          height: height,
          color: const Color(0xFFE0E0E0),
          child: const Center(
            child: Icon(Icons.image_outlined, color: Colors.white, size: 28),
          ),
        );
    if (url.isEmpty) return ph();
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      placeholder: (context, _) => ph(),
      errorWidget: (context, _, __) => ph(),
    );
  }
}
