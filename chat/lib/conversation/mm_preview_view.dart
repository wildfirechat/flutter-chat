import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imclient/imclient_platform.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/utils/duration_formatter.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/utils/non_cached_image.dart';
import 'package:chat/widget/drag_to_dismiss.dart';
import 'package:video_player/video_player.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_typography.dart';

typedef PageToEnd = void Function(int messageId, bool tail);

class MMPreviewView extends StatefulWidget {
  final List<Message> mediaItems; // 图片和视频列表
  final int defaultIndex; // 默认第几张
  final PageToEnd? pageToEnd; // 切换回调
  final Axis direction; // 查看方向
  final BoxDecoration? decoration; // 背景设计
  // 拖拽退出时缩回的目标(消息气泡缩略图)的全局 rect;返回 null 则退化为下滑退出
  final Rect? Function(Message message)? sourceRectProvider;
  // 桌面端关闭动作(独立预览窗口中是关窗);为空则退化为 Navigator.pop
  final VoidCallback? onClose;

  const MMPreviewView(this.mediaItems,
      {super.key,
      this.defaultIndex = 1,
      this.pageToEnd,
      this.direction = Axis.horizontal,
      this.decoration,
      this.sourceRectProvider,
      this.onClose});

  @override
  State<MMPreviewView> createState() => MMPreviewViewState();
}

class MMPreviewViewState extends State<MMPreviewView> {
  late int currentIndex;
  late PageController _pageController;
  bool isZoomed = false; // Add zoomed state
  // 每张图的旋转角(quarterTurns),按 messageId 存(onLoadMore 前插后 index 会变)
  final Map<int, int> _rotations = {};
  // 每张图一个缩放状态控制器(按 messageId 存,onLoadMore 前插后 index 会变)
  final Map<int, PhotoViewScaleStateController> _scaleStateControllers = {};
  // 每张图一个缩放控制器,桌面端滚轮/工具栏缩放需要读写 scale
  final Map<int, PhotoViewController> _photoControllers = {};
  // 当前挂载着的视频播放器控制器(按 messageId 存)。关闭预览前要主动暂停：
  // 桌面独立预览窗关闭时原生引擎可能被直接销毁，不一定会经过 MMVideoPlayer
  // 正常的 State.dispose() 流程，不主动 pause 的话窗口关掉后视频的声音还在放。
  final Map<int, VideoPlayerController> _videoControllers = {};

  // 桌面端键盘快捷键(方向键/Esc/空格)的焦点宿主。
  //
  // 用 FocusScope 而不是 Focus,有两个原因:
  //
  // 1) 必须在首帧后**显式** requestFocus,只写 autofocus 是不够的:子窗口基类
  //    SubWindowAppBase._wrapWithCloseShortcut 在更外层也挂了一个 autofocus 的
  //    Focus(用于 Ctrl/Cmd+W 关窗)。同一 FocusScope 内多个 autofocus 只有最先
  //    注册的那个生效(祖先先 build 先注册),而按键事件只从 primaryFocus 沿祖先
  //    链向「上」冒泡、不会下发给后代 —— 焦点被外层占住的话快捷键整体失灵。
  //
  // 2) 焦点一旦丢失,普通 Focus 会回落到「最近的祖先 scope」,也就是路由那个
  //    scope —— 它是本节点的祖先,于是按键再也到不了这里,快捷键就永久失效了
  //    (视频播完后出现的正是这种现象)。换成 FocusScope 后,最近的 scope 就是
  //    自己,任何后代放弃焦点都回落到本节点,按键链路不会断。
  //
  // 抢焦点不影响外层:本节点是它的后代,未消费的按键(Ctrl/Cmd+W)照样继续向上
  // 冒泡到基类节点。
  final FocusScopeNode _keyboardFocusNode =
      FocusScopeNode(debugLabel: 'MMPreviewKeyboard');

  // 焦点被外部抢走后重新夺回。仅在本路由仍在最前时执行,避免把焦点从弹出的
  // 倍速菜单/另存为对话框(它们是压在上面的独立路由)手里抢回来。
  void _ensureKeyboardFocus() {
    if (!mounted || !isDesktopShell) return;
    if (_keyboardFocusNode.hasFocus) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _keyboardFocusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    currentIndex = widget.defaultIndex;
    _pageController = PageController(initialPage: widget.defaultIndex);
    if (isDesktopShell) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureKeyboardFocus());
    }
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _pageController.dispose();
    for (final controller in _scaleStateControllers.values) {
      controller.dispose();
    }
    for (final controller in _photoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  PhotoViewScaleStateController _scaleStateControllerFor(int messageId) {
    return _scaleStateControllers.putIfAbsent(
        messageId, () => PhotoViewScaleStateController());
  }

  PhotoViewController _photoControllerFor(int messageId) {
    return _photoControllers.putIfAbsent(messageId, () => PhotoViewController());
  }

  int get _currentMessageId => widget.mediaItems[currentIndex].messageId;

  // 桌面端关闭:独立预览窗口里关窗,内嵌(对话框/整页路由)里出栈。
  // 关之前先暂停所有还挂着的视频，见 _videoControllers 的注释。
  void _requestClose() async {
    await pauseAllVideos();
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goToRelative(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _goToRelative(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _requestClose();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _handleSpaceKey();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // 空格键:图片页关闭预览(与 Esc 一致);视频页则切换播放/暂停,不关闭预览。
  void _handleSpaceKey() {
    final message = widget.mediaItems[currentIndex];
    if (message.content is VideoMessageContent) {
      final controller = _videoControllers[message.messageId];
      if (controller != null && controller.value.isInitialized) {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      }
      return;
    }
    _requestClose();
  }

  /// 暂停所有还挂着的视频。独立预览窗口(媒体预览子窗口)有系统标题栏关闭键，
  /// 走的是 window_manager 的原生关闭事件而不是本类的 [_requestClose]，
  /// 所以还要供 MediaPreviewWindowApp 在 onWindowClose 里主动调一次，
  /// 否则从系统标题栏关闭窗口时视频声音不会停。
  Future<void> pauseAllVideos() async {
    for (final controller in _videoControllers.values) {
      try {
        await controller.pause();
      } catch (_) {
        // 播放器可能已经在销毁中，忽略
      }
    }
  }

  // 参考微信:滚轮/工具栏按钮缩放当前图片,范围与手势缩放一致(contain ~ cover*2.5)
  void _zoomBy(double factor) {
    final Message message = widget.mediaItems[currentIndex];
    final content = message.content;
    if (content is! ImageMessageContent) return;
    final controller = _photoControllers[message.messageId];
    if (controller == null) return;
    final Size viewport = MediaQuery.of(context).size;
    final Size child = _imageChildSize(content, _rotations[message.messageId] ?? 0);
    final double contained =
        math.min(viewport.width / child.width, viewport.height / child.height);
    final double maxScale =
        math.max(viewport.width / child.width, viewport.height / child.height) * 2.5;
    final double current = controller.scale ?? contained;
    controller.scale = (current * factor).clamp(contained, maxScale).toDouble();
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
      final Size child = _imageChildSize(content, _rotations[_currentMessageId] ?? 0);
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
    // 桌面端翻页走两侧按钮/方向键(与微信一致),滚轮专用于缩放
    Widget gallery = PhotoViewGallery.builder(
              scrollPhysics: isDesktopShell
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                Message message = widget.mediaItems[index];

                if (message.content is ImageMessageContent) {
                  ImageMessageContent imageContent = message.content as ImageMessageContent;

                  // 优先检查本地文件（大图预览不进入 Flutter ImageCache）
                  if (imageContent.localPath != null && imageContent.localPath!.isNotEmpty) {
                    File localFile = File(imageContent.localPath!);
                    if (localFile.existsSync()) {
                      final rotation = _rotations[message.messageId] ?? 0;
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
                        controller: _photoControllerFor(message.messageId),
                        scaleStateController: _scaleStateControllerFor(message.messageId),
                      );
                    }
                  }

                  // 使用网络图片（大图预览不进入 Flutter ImageCache，仍复用磁盘缓存）
                  if (imageContent.remoteUrl != null && imageContent.remoteUrl!.isNotEmpty) {
                    final rotation = _rotations[message.messageId] ?? 0;
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
                      controller: _photoControllerFor(message.messageId),
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
                      onControllerReady: (controller) =>
                          _videoControllers[message.messageId] = controller,
                      onControllerDisposed: () =>
                          _videoControllers.remove(message.messageId),
                      // 图片的"另存为"在底部工具栏,视频没有那条工具栏,
                      // 改放到自己控制条的最右侧
                      onSave: _saveCurrentMedia,
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
                    if (index == _navTarget) {
                      _navTarget = null;
                    }
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
                  }));
    if (isDesktopShell) {
      // 参考微信:滚轮向上放大、向下缩小当前图片
      gallery = Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _zoomBy(math.exp(-event.scrollDelta.dy * 0.002));
          }
        },
        // 兜底:在预览里点一下就把键盘焦点收回来(符合直觉,也保证万一焦点被
        // 什么东西抢走,用户点一下画面即可恢复快捷键)
        onPointerDown: (_) => _ensureKeyboardFocus(),
        child: gallery,
      );
    }

    final content = Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          gallery,
          // 桌面端不再叠加悬浮关闭按钮:独立预览窗口有系统标题栏关闭键,ESC/空格也可关
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
                      onPressed: () => _goToRelative(-1),
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
                      onPressed: () => _goToRelative(1),
                      tooltip: AppLocalizations.of(context)!.nextImage,
                    ),
                  ),
                ),
              ),
            ),
          // 内嵌整页路由打开时(如搜索窗口/收藏预览)没有窗口关闭按钮，
          // 补一个右上角关闭按钮；独立预览窗口(onClose != null)由窗口 chrome 负责
          if (isDesktopShell && widget.onClose == null)
            Positioned(
              top: 16,
              right: 16,
              child: HoverBuilder(
                builder: (context, isHovered) => Material(
                  color: isHovered ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.25),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    onPressed: _requestClose,
                    tooltip: AppLocalizations.of(context)!.close,
                  ),
                ),
              ),
            ),
          // Bottom toolbar on desktop:缩放/旋转对视频没有意义,存储已挪到右键菜单,
          // 只在图片页显示;视频页由 MMVideoPlayer 自己的底部控制条负责。
          if (isDesktopShell && widget.mediaItems[currentIndex].content is ImageMessageContent)
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
                      // Zoom Out
                      IconButton(
                        icon: const Icon(Icons.zoom_out_rounded, color: Colors.white70, size: 20),
                        onPressed: () => _zoomBy(1 / 1.25),
                        tooltip: AppLocalizations.of(context)!.zoomOut,
                      ),
                      const SizedBox(width: 8),
                      // Zoom In
                      IconButton(
                        icon: const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 20),
                        onPressed: () => _zoomBy(1.25),
                        tooltip: AppLocalizations.of(context)!.zoomIn,
                      ),
                      const SizedBox(width: 8),
                      // Rotate Left
                      IconButton(
                        icon: const Icon(Icons.rotate_left_rounded, color: Colors.white70, size: 20),
                        onPressed: () {
                          setState(() {
                            _rotations[_currentMessageId] = ((_rotations[_currentMessageId] ?? 0) - 1 + 4) % 4;
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
                            _rotations[_currentMessageId] = ((_rotations[_currentMessageId] ?? 0) + 1) % 4;
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
      // 用 onKeyEvent 而不是 CallbackShortcuts:空格要按当前页是图片还是视频
      // 分别做关窗/播放暂停,SingleActivator 表达不了这种条件分支。
      // 用 FocusScope 且显式抢焦点,原因见 _keyboardFocusNode 的注释。
      return FocusScope(
        node: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        onFocusChange: (hasFocus) {
          // 焦点被抢走时(且没有别的路由压在上面)下一帧夺回来
          if (!hasFocus) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _ensureKeyboardFocus());
          }
        },
        // 内部按钮(翻页/工具栏)点击后不许夺焦,否则空格会重触发该按钮而非关窗
        child: ExcludeFocus(
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

  // 长按方向键时按键连发比翻页动画快:animateToPage 未落定 currentIndex 就收到
  // 下一次按键,若仍以 currentIndex 为基准会反复朝同一页做动画,表现为"一点点
  // 移动"。以导航目标累进才能一次按键实打实翻一页,到达后清空回归 currentIndex。
  int? _navTarget;

  void _goToRelative(int delta) {
    _goToPage((_navTarget ?? currentIndex) + delta);
  }

  void _goToPage(int index) {
    if (index < 0 || index >= widget.mediaItems.length) return;
    _navTarget = index;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
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
        showToast(msg: l10n.saveSuccess);
      } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(remoteUrl));
        final response = await request.close();
        final bytes = await response.fold<List<int>>([], (prev, element) => prev..addAll(element));
        await File(outputFile).writeAsBytes(bytes);
        showToast(msg: l10n.saveSuccess);
      } else {
        showToast(msg: l10n.saveFailSourceMissing);
      }
    } catch (e) {
      showToast(msg: l10n.saveFail('$e'));
    }
  }
}

class MMVideoPlayer extends StatefulWidget {
  final VideoMessageContent content;
  final VoidCallback? onTap;
  // 播放器初始化成功/销毁时上报给父级(按 messageId 记录当前挂载的控制器),
  // 关闭预览前父级要用它主动 pause，见 MMPreviewViewState._videoControllers。
  final ValueChanged<VideoPlayerController>? onControllerReady;
  final VoidCallback? onControllerDisposed;
  // 控制条上的"另存为";为空则不显示该按钮
  final VoidCallback? onSave;

  const MMVideoPlayer(this.content,
      {super.key,
      this.onTap,
      this.onControllerReady,
      this.onControllerDisposed,
      this.onSave});

  @override
  State<MMVideoPlayer> createState() => _MMVideoPlayerState();
}

class _MMVideoPlayerState extends State<MMVideoPlayer> {
  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  late VideoPlayerController _controller;
  // 触屏端靠点击切换控制条显隐;桌面端改由 _hovering 驱动(见 _controlsVisible)
  bool _showControls = false;
  bool _hovering = false;
  double _playbackSpeed = 1.0;
  double _volumeBeforeMute = 1.0;
  bool _isMuted = false;
  // 拖动进度条时先本地记着目标位置,松手才真正 seek,避免拖动过程中
  // 控制器的 position 更新和手指位置打架导致进度条抖动。
  double? _dragPositionMs;

  @override
  void initState() {
    super.initState();
    // Windows/macOS/Linux 由 fvp 补上了 video_player 桌面后端(见 main.dart 的
    // 注册调用)，可以直接用 VideoPlayerController；鸿蒙电脑没有覆盖，
    // 仍降级为系统播放器打开
    if (!WfcPlatform.isOhosPc) {
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

    // 播放/暂停按钮、加载态都要跟着控制器的真实状态走(而不是只在手动调用的
    // 地方 setState),否则视频自然播完、缓冲等控制器自己触发的变化不会反映到
    // UI 上，按钮状态就会跟实际播放状态对不上。
    _controller.addListener(_onControllerValueChanged);
    _controller.initialize().then((_) {
      if (mounted) {
        _controller.play();
        widget.onControllerReady?.call(_controller);
      }
    });
  }

  void _onControllerValueChanged() {
    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _toggleMute() {
    setState(() {
      if (_isMuted) {
        _controller.setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 1.0);
        _isMuted = false;
      } else {
        _volumeBeforeMute = _controller.value.volume > 0 ? _controller.value.volume : 1.0;
        _controller.setVolume(0);
        _isMuted = true;
      }
    });
  }

  // 控制条显隐:桌面端跟随鼠标悬停,触屏端跟随点击;暂停时常驻。
  // 拖进度条时也常驻 —— 拖动中指针很容易划出视频区域触发 onExit,
  // 控制条中途消失会把这一次拖拽也一起打断。
  bool get _controlsVisible =>
      (isDesktopShell ? _hovering : _showControls) ||
      !_controller.value.isPlaying ||
      _dragPositionMs != null;

  // 底部视频控制条:播放/暂停、进度条(可拖拽 seek)、倍速、静音。
  // 拖动进度条时用 _dragPositionMs 顶替真实 position 显示,松手才真正 seek,
  // 否则拖动中控制器自己上报的 position 会和手指位置打架导致进度条抖动。
  Widget _buildControlBar() {
    final VideoPlayerValue value = _controller.value;
    final Duration total = value.duration;
    final double totalMs = total.inMilliseconds.toDouble();
    final double currentMs = (_dragPositionMs ?? value.position.inMilliseconds.toDouble())
        .clamp(0.0, totalMs > 0 ? totalMs : 1.0);
    final bool muted = _isMuted || value.volume <= 0;
    final l10n = AppLocalizations.of(context)!;

    return Positioned(
      left: 24,
      right: 24,
      bottom: isDesktopShell ? 30 : (24 + MediaQuery.of(context).padding.bottom),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _togglePlayPause,
              child: Icon(
                value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Text(formatMediaDuration(currentMs.round()),
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: currentMs,
                  min: 0,
                  max: totalMs > 0 ? totalMs : 1.0,
                  onChangeStart: totalMs > 0 ? (v) => setState(() => _dragPositionMs = v) : null,
                  onChanged: totalMs > 0 ? (v) => setState(() => _dragPositionMs = v) : null,
                  onChangeEnd: totalMs > 0
                      ? (v) async {
                          await _controller.seekTo(Duration(milliseconds: v.round()));
                          if (mounted) setState(() => _dragPositionMs = null);
                        }
                      : null,
                ),
              ),
            ),
            Text(formatMediaDuration(total.inMilliseconds),
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            const SizedBox(width: 10),
            PopupMenuButton<double>(
              tooltip: l10n.playbackSpeed,
              color: Colors.black87,
              position: PopupMenuPosition.over,
              onSelected: (speed) {
                setState(() => _playbackSpeed = speed);
                _controller.setPlaybackSpeed(speed);
              },
              itemBuilder: (context) => _speedOptions
                  .map((speed) => PopupMenuItem<double>(
                        value: speed,
                        child: Text(
                          '${speed}x',
                          style: TextStyle(
                            color: speed == _playbackSpeed
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white,
                          ),
                        ),
                      ))
                  .toList(),
              child: Text(l10n.playbackSpeed, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: muted ? l10n.unmute : l10n.mute,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Icon(
                  muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            if (widget.onSave != null) ...[
              const SizedBox(width: 10),
              Tooltip(
                message: l10n.saveAs,
                child: GestureDetector(
                  onTap: widget.onSave,
                  child: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    final thumbnail = widget.content.thumbnail;
    if (thumbnail == null) {
      return const ColoredBox(color: Colors.black);
    }
    return ColoredBox(
      color: Colors.black,
      child: Image.memory(
        thumbnail,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      ),
    );
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
    if (!WfcPlatform.isOhosPc) {
      _controller.removeListener(_onControllerValueChanged);
      widget.onControllerDisposed?.call();
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (WfcPlatform.isOhosPc) {
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
                  AppLocalizations.of(context)!.openWithSystemPlayer,
                  style: AppText.base.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget player = GestureDetector(
      onTap: () {
        setState(() {
          // 桌面端控制条常驻于悬停,点击画面直接播放/暂停(与空格键一致);
          // 触屏端没有悬停,仍沿用点击切换控制条显隐
          if (isDesktopShell) {
            _togglePlayPause();
          } else {
            _showControls = !_showControls;
          }
        });
        widget.onTap?.call();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 加载完成前用视频封面(消息自带的缩略图)占位,不然初始化好之前
          // 只有一个黑底转圈,体验很差
          if (!_controller.value.isInitialized)
            Positioned.fill(child: _buildCoverPlaceholder()),
          Center(
            child: _controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
          // 播放/暂停已经交给底部控制条和空格键,不再需要居中的大按钮
          if (_controller.value.isInitialized && _controlsVisible) _buildControlBar(),
        ],
      ),
    );

    if (isDesktopShell) {
      // 鼠标移到视频上就显示控制条(移开即隐),不用点一下才出来
      player = MouseRegion(
        onEnter: (_) {
          if (!_hovering) setState(() => _hovering = true);
        },
        onExit: (_) {
          if (_hovering) setState(() => _hovering = false);
        },
        child: player,
      );
    }
    return player;
  }
}
