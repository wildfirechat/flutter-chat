import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:chat/theme/app_colors.dart';
import 'sticker_loader.dart';
import 'sticker_source.dart';

/// 显示一个贴纸:图片(含 GIF/动态 WebP)或 Lottie(Telegram .tgs)。
///
/// 给了 [width]/[height] 时占满该尺寸并等比缩放居中;不给则按贴纸固有尺寸在父约束内自适应。
/// 动画受 [TickerMode] 控制,放在不可见的页面里会自动暂停。
class StickerView extends StatefulWidget {
  const StickerView(
    this.source, {
    super.key,
    this.width,
    this.height,
    this.animate = true,
    this.decodeSize,
  });

  final StickerSource source;
  final double? width;
  final double? height;

  /// false 时 Lottie 停在第 0 帧(内置贴纸包保证第 0 帧是完整画面)。
  /// 动图由图片解码器驱动,不受此开关影响。
  final bool animate;

  /// 图片贴纸的解码边长(物理像素)。默认取显示尺寸 × dpr,尺寸未知时 400。
  final int? decodeSize;

  /// Lottie 的播放帧率上限。贴纸在小尺寸下 30fps 与 60fps 肉眼几乎无差,
  /// 渲染与绘制指令缓存都减半。
  static const FrameRate _frameRate = FrameRate(30);

  @override
  State<StickerView> createState() => _StickerViewState();
}

class _StickerViewState extends State<StickerView> {
  LoadedSticker? _sticker;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(StickerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _resolve();
    }
  }

  void _resolve() {
    final source = widget.source;
    _failed = false;
    _sticker = StickerLoader.peek(source);
    if (_sticker != null) {
      return;
    }
    StickerLoader.load(source).then((sticker) {
      if (mounted && widget.source == source) {
        setState(() => _sticker = sticker);
      }
    }, onError: (Object error) {
      debugPrint('load sticker $source failed: $error');
      if (mounted && widget.source == source) {
        setState(() => _failed = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sticker = _sticker;
    if (_failed) {
      return _brokenPlaceholder(context);
    }
    if (sticker == null) {
      return SizedBox(width: widget.width, height: widget.height);
    }

    final composition = sticker.composition;
    if (composition != null) {
      return Lottie(
        composition: composition,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.contain,
        animate: widget.animate,
        frameRate: StickerView._frameRate,
        // 每帧的绘制指令录一次后复用,省掉逐帧遍历图层的 CPU 开销;
        // 同一贴纸在多处显示时共享缓存,组件销毁即释放
        renderCache: RenderCache.drawingCommands,
      );
    }

    final side = math.max(widget.width ?? 0, widget.height ?? 0);
    final decodeSize = widget.decodeSize ??
        (side > 0
            ? (side * MediaQuery.devicePixelRatioOf(context)).ceil()
            : 400);
    return Image(
      // 等比缩进 decodeSize 方框内解码:避免原图全尺寸解码占内存,也不把非方形贴纸压扁
      image: ResizeImage(
        sticker.image!,
        width: decodeSize,
        height: decodeSize,
        policy: ResizeImagePolicy.fit,
        allowUpscaling: false,
      ),
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => _brokenPlaceholder(context),
    );
  }

  Widget _brokenPlaceholder(BuildContext context) {
    final side =
        math.min(math.max(widget.width ?? 0, widget.height ?? 0) * 0.6, 48.0);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: side > 0 ? side : 48,
          color: context.colors.iconSecondary,
        ),
      ),
    );
  }
}
