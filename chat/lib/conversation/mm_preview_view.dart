import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/utils/non_cached_image.dart';
import 'package:chat/widget/drag_to_dismiss.dart';
import 'package:video_player/video_player.dart';
import 'package:chat/l10n/app_localizations.dart';

typedef PageToEnd = void Function(int messageId, bool tail);

class MMPreviewView extends StatefulWidget {
  final List<Message> mediaItems; // 图片和视频列表
  final int defaultIndex; // 默认第几张
  final PageToEnd? pageToEnd; // 切换回调
  final Axis direction; // 查看方向
  final BoxDecoration? decoration; // 背景设计
  // 拖拽退出时缩回的目标(消息气泡缩略图)的全局 rect;返回 null 则退化为下滑退出
  final Rect? Function(Message message)? sourceRectProvider;

  const MMPreviewView(this.mediaItems,
      {super.key,
      this.defaultIndex = 1,
      this.pageToEnd,
      this.direction = Axis.horizontal,
      this.decoration,
      this.sourceRectProvider});

  @override
  State<MMPreviewView> createState() => MMPreviewViewState();
}

class MMPreviewViewState extends State<MMPreviewView> {
  late int currentIndex;
  late PageController _pageController;
  bool isZoomed = false; // Add zoomed state
  final Map<int, int> _rotations = {};
  // 每张图一个缩放状态控制器(按 messageId 存,onLoadMore 前插后 index 会变)
  final Map<int, PhotoViewScaleStateController> _scaleStateControllers = {};

  @override
  void initState() {
    super.initState();
    currentIndex = widget.defaultIndex;
    _pageController = PageController(initialPage: widget.defaultIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _scaleStateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  PhotoViewScaleStateController _scaleStateControllerFor(int messageId) {
    return _scaleStateControllers.putIfAbsent(
        messageId, () => PhotoViewScaleStateController());
  }

  // 有原始宽高时用真实尺寸,photo_view 的缩放边界/边缘吸附才准确;缺失时退回屏幕尺寸。
  // 旋转 90°/270° 时宽高互换(桌面端工具栏可旋转)。
  Size _imageChildSize(ImageMessageContent content, int quarterTurns) {
    final double w = content.width.toDouble();
    final double h = content.height.toDouble();
    if (w <= 0 || h <= 0) {
      return MediaQuery.of(context).size;
    }
    return quarterTurns.isOdd ? Size(h, w) : Size(w, h);
  }

  // 当前页媒体静止时在屏幕上的显示区域(contain 适配);尺寸未知或视频时为全屏
  Rect _currentContentRect() {
    final Size screen = MediaQuery.of(context).size;
    final content = widget.mediaItems[currentIndex].content;
    if (content is ImageMessageContent) {
      final Size child = _imageChildSize(content, _rotations[currentIndex] ?? 0);
      if (child != screen) {
        final double s =
            math.min(screen.width / child.width, screen.height / child.height);
        return Rect.fromCenter(
            center: screen.center(Offset.zero),
            width: child.width * s,
            height: child.height * s);
      }
    }
    return Offset.zero & screen;
  }

  void onLoadMore(List<Message> moreItems, bool front) {
    setState(() {
      if (front) {
        moreItems.addAll(widget.mediaItems);
        widget.mediaItems.clear();
      }
      widget.mediaItems.addAll(moreItems);
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                Message message = widget.mediaItems[index];

                if (message.content is ImageMessageContent) {
                  ImageMessageContent imageContent = message.content as ImageMessageContent;

                  // 优先检查本地文件（大图预览不进入 Flutter ImageCache）
                  if (imageContent.localPath != null && imageContent.localPath!.isNotEmpty) {
                    File localFile = File(imageContent.localPath!);
                    if (localFile.existsSync()) {
                      final rotation = _rotations[index] ?? 0;
                      final Size childSize = _imageChildSize(imageContent, rotation);
                      final Size screenSize = MediaQuery.of(context).size;
                      // childSize 为原图尺寸时整页被 contained 比例缩放,占位/错误图标反向缩放保持视觉大小
                      final double containedScale = math.min(
                          screenSize.width / childSize.width, screenSize.height / childSize.height);
                      Widget keepVisualSize(Widget child) => Center(
                          child: Transform.scale(scale: 1 / containedScale, child: child));
                      return PhotoViewGalleryPageOptions.customChild(
                        child: RotatedBox(
                          quarterTurns: rotation,
                          child: NonCachedImage.file(
                            path: imageContent.localPath!,
                            placeholder: keepVisualSize(
                              const CircularProgressIndicator(strokeWidth: 2, color: Colors.white30),
                            ),
                            errorWidget: keepVisualSize(
                              const Icon(
                                Icons.broken_image_rounded,
                                color: Colors.white30,
                                size: 48,
                              ),
                            ),
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                        childSize: childSize,
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 2.5,
                        scaleStateController: _scaleStateControllerFor(message.messageId),
                      );
                    }
                  }

                  // 使用网络图片（大图预览不进入 Flutter ImageCache，仍复用磁盘缓存）
                  if (imageContent.remoteUrl != null && imageContent.remoteUrl!.isNotEmpty) {
                    final rotation = _rotations[index] ?? 0;
                    final Size childSize = _imageChildSize(imageContent, rotation);
                    final Size screenSize = MediaQuery.of(context).size;
                    // childSize 为原图尺寸时整页被 contained 比例缩放,占位/错误图标反向缩放保持视觉大小
                    final double containedScale = math.min(
                        screenSize.width / childSize.width, screenSize.height / childSize.height);
                    Widget keepVisualSize(Widget child) => Center(
                        child: Transform.scale(scale: 1 / containedScale, child: child));
                    return PhotoViewGalleryPageOptions.customChild(
                      child: RotatedBox(
                        quarterTurns: rotation,
                        child: NonCachedImage.network(
                          url: MediaUrlRedirector.redirect(imageContent.remoteUrl!),
                          placeholder: keepVisualSize(
                            const CircularProgressIndicator(strokeWidth: 2, color: Colors.white30),
                          ),
                          errorWidget: keepVisualSize(
                            const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white30,
                              size: 48,
                            ),
                          ),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      childSize: childSize,
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 2.5,
                      scaleStateController: _scaleStateControllerFor(message.messageId),
                    );
                  }

                  // 默认占位符
                  return PhotoViewGalleryPageOptions(
                    imageProvider: const AssetImage('assets/images/placeholder.png'),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 2.5,
                  );
                } else if (message.content is VideoMessageContent) {
                  VideoMessageContent videoContent = message.content as VideoMessageContent;
                  return PhotoViewGalleryPageOptions.customChild(
                    child: MMVideoPlayer(
                      videoContent,
                      onTap: () {
                        // Toggle controls or whatever if needed, or handle in player
                      },
                    ),
                    childSize: MediaQuery.of(context).size,
                    initialScale: PhotoViewComputedScale.contained,
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.contained, // Video usually doesn't zoom
                    heroAttributes: PhotoViewHeroAttributes(tag: message.messageUid ?? message.messageId),
                  );
                }

                return PhotoViewGalleryPageOptions(
                    imageProvider: const AssetImage('assets/images/placeholder.png'),
                );
              },
              scrollDirection: widget.direction,
              itemCount: widget.mediaItems.length,
              backgroundDecoration: widget.decoration ??
                  const BoxDecoration(color: Colors.transparent),
              pageController: _pageController,
              // 双指缩放、双击缩放(含动画中途)都会走这里,isZoomed 驱动 DragToDismiss 开关
              scaleStateChangedCallback: (state) {
                final bool zoomed = state != PhotoViewScaleState.initial;
                if (zoomed != isZoomed) {
                  setState(() => isZoomed = zoomed);
                }
              },
              onPageChanged: (index) => setState(() {
                    currentIndex = index;
                    isZoomed = false;
                    // 参考微信:切走页面时复位缩放,切回来是初始大小
                    for (final controller in _scaleStateControllers.values) {
                      controller.reset();
                    }
                    if (widget.pageToEnd != null) {
                      Message message = widget.mediaItems[index];
                      if (index == 0) {
                        widget.pageToEnd!(message.messageId, false);
                      } else if (index == widget.mediaItems.length - 1) {
                        widget.pageToEnd!(message.messageId, true);
                      }
                    }
                  })),
          // Left chevron button on desktop
          if (isDesktopShell && currentIndex > 0)
            Positioned(
              left: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: HoverBuilder(
                  builder: (context, isHovered) => Material(
                    color: isHovered ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.25),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 36),
                      onPressed: () => _goToPage(currentIndex - 1),
                      tooltip: AppLocalizations.of(context)!.previousImage,
                    ),
                  ),
                ),
              ),
            ),
          // Right chevron button on desktop
          if (isDesktopShell && currentIndex < widget.mediaItems.length - 1)
            Positioned(
              right: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: HoverBuilder(
                  builder: (context, isHovered) => Material(
                    color: isHovered ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.25),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 36),
                      onPressed: () => _goToPage(currentIndex + 1),
                      tooltip: AppLocalizations.of(context)!.nextImage,
                    ),
                  ),
                ),
              ),
            ),
          // Bottom toolbar on desktop
          if (isDesktopShell)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rotate Left
                      IconButton(
                        icon: const Icon(Icons.rotate_left_rounded, color: Colors.white70, size: 20),
                        onPressed: () {
                          setState(() {
                            _rotations[currentIndex] = ((_rotations[currentIndex] ?? 0) - 1 + 4) % 4;
                          });
                        },
                        tooltip: AppLocalizations.of(context)!.rotateLeft,
                      ),
                      const SizedBox(width: 8),
                      // Rotate Right
                      IconButton(
                        icon: const Icon(Icons.rotate_right_rounded, color: Colors.white70, size: 20),
                        onPressed: () {
                          setState(() {
                            _rotations[currentIndex] = ((_rotations[currentIndex] ?? 0) + 1) % 4;
                          });
                        },
                        tooltip: AppLocalizations.of(context)!.rotateRight,
                      ),
                      const SizedBox(width: 8),
                      // Save As
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: Colors.white70, size: 20),
                        onPressed: _saveCurrentMedia,
                        tooltip: AppLocalizations.of(context)!.saveAs,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (isDesktopShell) {
      // 桌面端：黑色背景、键盘翻页、禁用拖拽关闭
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            _goToPage(currentIndex - 1);
          },
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            _goToPage(currentIndex + 1);
          },
          const SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.pop(context);
          },
        },
        child: Focus(
          autofocus: true,
          child: Container(
            color: Colors.black,
            child: content,
          ),
        ),
      );
    }

    // 手机端：保持拖拽关闭手势
    return DragToDismiss(
      enabled: !isZoomed,
      contentRect: _currentContentRect,
      dismissTargetRect: widget.sourceRectProvider == null
          ? null
          : () => widget.sourceRectProvider!(widget.mediaItems[currentIndex]),
      onDismiss: () {
        Navigator.pop(context);
      },
      child: content,
    );
  }

  void _goToPage(int index) {
    if (index < 0 || index >= widget.mediaItems.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _saveCurrentMedia() async {
    // 跨多个 await 使用,先取好文案
    final l10n = AppLocalizations.of(context)!;
    final message = widget.mediaItems[currentIndex];
    String? sourcePath;
    String? remoteUrl;
    String fileName = 'file';

    if (message.content is ImageMessageContent) {
      final content = message.content as ImageMessageContent;
      sourcePath = content.localPath;
      remoteUrl = content.remoteUrl;
      fileName = 'image_${message.messageUid ?? message.messageId}.jpg';
      if (remoteUrl != null) {
        remoteUrl = MediaUrlRedirector.redirect(remoteUrl);
        final uri = Uri.parse(remoteUrl);
        if (uri.pathSegments.isNotEmpty) {
          fileName = uri.pathSegments.last;
        }
      }
    } else if (message.content is VideoMessageContent) {
      final content = message.content as VideoMessageContent;
      sourcePath = content.localPath;
      remoteUrl = content.remoteUrl;
      fileName = 'video_${message.messageUid ?? message.messageId}.mp4';
      if (remoteUrl != null) {
        remoteUrl = MediaUrlRedirector.redirect(remoteUrl);
        final uri = Uri.parse(remoteUrl);
        if (uri.pathSegments.isNotEmpty) {
          fileName = uri.pathSegments.last;
        }
      }
    }

    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: l10n.saveFile,
        fileName: fileName,
      );
      if (outputFile == null) return;

      if (sourcePath != null && File(sourcePath).existsSync()) {
        await File(sourcePath).copy(outputFile);
        Fluttertoast.showToast(msg: l10n.saveSuccess);
      } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(remoteUrl));
        final response = await request.close();
        final bytes = await response.fold<List<int>>([], (prev, element) => prev..addAll(element));
        await File(outputFile).writeAsBytes(bytes);
        Fluttertoast.showToast(msg: l10n.saveSuccess);
      } else {
        Fluttertoast.showToast(msg: l10n.saveFailSourceMissing);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: l10n.saveFail('$e'));
    }
  }
}

class MMVideoPlayer extends StatefulWidget {
  final VideoMessageContent content;
  final VoidCallback? onTap;

  const MMVideoPlayer(this.content, {super.key, this.onTap});

  @override
  State<MMVideoPlayer> createState() => _MMVideoPlayerState();
}

class _MMVideoPlayerState extends State<MMVideoPlayer> {
  late VideoPlayerController _controller;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    // 桌面端 video_player 官方无 Windows/Linux 实现，直接降级为系统播放器打开
    if (!isDesktopShell) {
      _initializeController();
    }
  }

  void _initializeController() {
    if (widget.content.localPath != null && widget.content.localPath!.isNotEmpty && File(widget.content.localPath!).existsSync()) {
      _controller = VideoPlayerController.file(File(widget.content.localPath!));
    } else if (widget.content.remoteUrl != null && widget.content.remoteUrl!.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(MediaUrlRedirector.redirect(widget.content.remoteUrl!)));
    } else {
       // fallback or error handling
       _controller = VideoPlayerController.networkUrl(Uri.parse(""));
    }

    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _controller.play();
      }
    });
  }

  Future<void> _openWithSystemPlayer() async {
    final videoUrl = widget.content.localPath != null && widget.content.localPath!.isNotEmpty && File(widget.content.localPath!).existsSync()
        ? Uri.file(widget.content.localPath!)
        : (widget.content.remoteUrl != null ? Uri.parse(MediaUrlRedirector.redirect(widget.content.remoteUrl!)) : null);
    if (videoUrl != null && await canLaunchUrl(videoUrl)) {
      await launchUrl(videoUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    if (!isDesktopShell) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktopShell) {
      return GestureDetector(
        onTap: _openWithSystemPlayer,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_outline, color: Colors.white.withValues(alpha: 0.8), size: 64),
                const SizedBox(height: 12),
                Text(
                  '点击用系统播放器打开',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
        widget.onTap?.call();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: _controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
          if (_showControls || !_controller.value.isPlaying)
            Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
