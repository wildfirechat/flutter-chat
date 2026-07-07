import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/widget/drag_to_dismiss.dart';
import 'package:video_player/video_player.dart';

typedef PageToEnd = void Function(int messageId, bool tail);

class MMPreviewView extends StatefulWidget {
  final List<Message> mediaItems; // 图片和视频列表
  final int defaultIndex; // 默认第几张
  final PageToEnd? pageToEnd; // 切换回调
  final Axis direction; // 查看方向
  final BoxDecoration? decoration; // 背景设计

  const MMPreviewView(this.mediaItems,
      {super.key,
      this.defaultIndex = 1,
      this.pageToEnd,
      this.direction = Axis.horizontal,
      this.decoration});

  @override
  State<MMPreviewView> createState() => MMPreviewViewState();
}

class MMPreviewViewState extends State<MMPreviewView> {
  late int currentIndex;
  bool isZoomed = false; // Add zoomed state
  bool isDragging = false;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.defaultIndex;
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
    // Wrap with DragToDismiss
    // Enable drag only when NOT zoomed
    return DragToDismiss(
      enabled: !isZoomed,
      onDismiss: () {
        Navigator.pop(context);
      },
      onDragStart: () {
        setState(() {
          isDragging = true;
        });
      },
      onDragEnd: () {
        setState(() {
          isDragging = false;
        });
      },
      child: Material(
        color: Colors.transparent, // Ensure Material is transparent
        child: Stack(
          children: [
            PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                builder: (BuildContext context, int index) {
                  Message message = widget.mediaItems[index];

                  if (message.content is ImageMessageContent) {
                    ImageMessageContent imageContent = message.content as ImageMessageContent;

                    // 优先检查本地文件
                    if (imageContent.localPath != null && imageContent.localPath!.isNotEmpty) {
                      File localFile = File(imageContent.localPath!);
                      if (localFile.existsSync()) {
                        return PhotoViewGalleryPageOptions(
                          imageProvider: FileImage(localFile),
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: PhotoViewComputedScale.covered * 2.5,
                          onScaleEnd: (context, details, controllerValue) {
                            setState(() {
                              isZoomed = controllerValue.scale! > 1.05;
                            });
                          },
                        );
                      }
                    }

                    // 使用网络图片（带缓存）
                    if (imageContent.remoteUrl != null && imageContent.remoteUrl!.isNotEmpty) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider: CachedNetworkImageProvider(imageContent.remoteUrl!),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 2.5,
                        onScaleEnd: (context, details, controllerValue) {
                          setState(() {
                            isZoomed = controllerValue.scale! > 1.05;
                          });
                        },
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
                pageController:
                    PageController(initialPage: widget.defaultIndex),
                onPageChanged: (index) => setState(() {
                      currentIndex = index;
                      isZoomed = false;
                      if (widget.pageToEnd != null) {
                        Message message = widget.mediaItems[index];
                        if (index == 0) {
                          widget.pageToEnd!(message.messageId, false);
                        } else if (index == widget.mediaItems.length - 1) {
                          widget.pageToEnd!(message.messageId, true);
                        }
                      }
                    })),
            if (!isDragging)
              Positioned(
                bottom: 20,
                child: Container(
                    alignment: Alignment.center,
                    width: MediaQuery.of(context).size.width,
                    child: Text(
                        "${currentIndex + 1}/${widget.mediaItems.length}",
                        style: const TextStyle(
                          decoration: TextDecoration.none,
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          shadows: [
                            Shadow(color: Colors.black, offset: Offset(1, 1)),
                          ],
                        ))),
              ),
            if (!isDragging)
              Positioned(
                //右上角关闭
                top: 60,
                right: 40,
                child: Container(
                  alignment: Alignment.centerLeft,
                  width: 20,
                  child: GestureDetector(
                    onTap: () {
                      //隐藏预览
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
            if (!isDragging)
              Positioned(
                //数量显示
                right: 20,
                top: 20,
                child: Text(
                  '${currentIndex + 1}/${widget.mediaItems.length}',
                  style: const TextStyle(
                      color: Colors
                          .white),
                ),
              )
          ],
        ),
      ),
    );
  }
}

class MMVideoPlayer extends StatefulWidget {
  final VideoMessageContent content;
  final VoidCallback? onTap;

  const MMVideoPlayer(this.content, {Key? key, this.onTap}) : super(key: key);

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
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.content.remoteUrl!));
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
        : (widget.content.remoteUrl != null ? Uri.parse(widget.content.remoteUrl!) : null);
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
                Icon(Icons.play_circle_outline, color: Colors.white.withOpacity(0.8), size: 64),
                const SizedBox(height: 12),
                Text(
                  '点击用系统播放器打开',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
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
                    color: Colors.black.withOpacity(0.5),
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
