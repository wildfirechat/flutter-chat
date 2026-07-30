import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:window_manager/window_manager.dart';

import '../../conversation/mm_preview_view.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/show_toast.dart';
import '../multi_window/ipc_codec.dart';
import '../multi_window/sub_window_app_base.dart';
import '../multi_window/window_event_channel.dart';
import 'media_preview_ipc.dart';
import 'media_preview_window_size.dart';

/// 媒体预览窗口的入口 Widget(参考微信:图片/视频在独立窗口中查看)。
///
/// 运行在独立的 Flutter Engine / Dart isolate 中,不连接 IM;
/// 翻页加载更多媒体通过 [WindowEventChannel] 请求主窗口代查。
/// 窗口初始化/标题/主题/关窗通知等样板见 [SubWindowAppBase]。
class MediaPreviewWindowApp extends StatefulWidget {
  final int windowId;
  final Map<String, dynamic> arguments;

  const MediaPreviewWindowApp({
    super.key,
    required this.windowId,
    required this.arguments,
  });

  @override
  State<MediaPreviewWindowApp> createState() => _MediaPreviewWindowAppState();
}

class _MediaPreviewWindowAppState extends State<MediaPreviewWindowApp>
    with WindowListener, SubWindowAppBase<MediaPreviewWindowApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey();
  GlobalKey<MMPreviewViewState> _previewKey = GlobalKey();
  List<Message> _mediaItems = [];
  int _defaultIndex = 0;
  Conversation? _conversation;

  /// 期望的窗口尺寸;window_manager 未就绪时先记着,[applyWindowStyle] 后补上。
  Size? _wantedWindowSize;
  Timer? _resizeTimer;
  bool _resizing = false;

  @override
  void initState() {
    super.initState();
    // 桌面端 showToast 依附 Navigator 的 Overlay(另存为的结果提示)。
    setToastNavigatorKey(_navigatorKey);
  }

  @override
  void dispose() {
    _resizeTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------- 基类钩子

  @override
  int get windowId => widget.windowId;

  @override
  Map<String, dynamic> get windowArguments => widget.arguments;

  /// 注意:事件前缀是 'mediaPreview.'(与现网事件名一致),
  /// 不是 kMediaPreviewWindowKind 的下划线形式。
  @override
  String get windowKind => 'mediaPreview';

  @override
  Size get minWindowSize => const Size(640, 480);

  /// 预览窗是黑色全屏查看器,强制暗色主题。
  @override
  ThemeData buildLightTheme() => ThemeData.dark();
  @override
  ThemeData buildDarkTheme() => ThemeData.dark();
  @override
  ThemeMode get themeMode => ThemeMode.dark;

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  @override
  Map<String, Future<dynamic> Function(dynamic)> get eventHandlers => {
        MediaPreviewEvents.show: _handleShow,
      };

  @override
  String windowTitle(AppLocalizations l10n) => l10n.mediaPreviewTitle;

  @override
  Future<void> onWindowReady() async {
    _applyPayload(windowArguments);
  }

  /// 就绪通知 fire-and-forget(主窗口收到后才推 show 事件,无需等待回执)。
  @override
  Future<void> notifyReady() {
    WindowEventChannel.invoke(0, MediaPreviewEvents.ready, {
      'windowId': windowId,
    });
    return Future.value();
  }

  /// 系统标题栏关闭键触发的关窗(跟 [_close] 是两条不同的路径:那个是
  /// ESC/应用内关闭键，主动调 WindowController.close；这个是用户直接点了
  /// 原生标题栏的关闭按钮，走 window_manager 的原生关闭事件)。同样要先暂停
  /// 视频，不然从系统标题栏关闭窗口时视频声音不会停。
  @override
  void onWindowClose() async {
    await _previewKey.currentState?.pauseAllVideos();
    super.onWindowClose();
  }

  /// window_manager 就绪前提过的尺寸要求(如视频初始化很快,先于窗口初始化
  /// 就报上来了)在这里补做。
  @override
  Future<void> applyWindowStyle() async {
    await super.applyWindowStyle();
    await _applyWantedWindowSize();
  }

  @override
  Widget buildHome(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _mediaItems.isEmpty
          ? const SizedBox.shrink()
          : MMPreviewView(
              _mediaItems,
              key: _previewKey,
              defaultIndex: _defaultIndex,
              pageToEnd: _loadMore,
              onClose: requestClose,
              onCurrentMediaChanged: _onCurrentMediaChanged,
            ),
    );
  }

  /// 未 ready 只有一个微任务间隙,保持与空内容一致的黑屏。
  @override
  Widget buildLoading(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.shrink(),
    );
  }

  // -------------------------------------------------------------- 业务

  void _applyPayload(Map<String, dynamic> args) {
    final items = MediaPreviewCodec.decodeMessages(args['items'] as List? ?? const []);
    int index = args['defaultIndex'] as int? ?? 0;
    if (index < 0 || index >= items.length) {
      index = 0;
    }
    final conversationMap = args['conversation'] as Map<String, dynamic>?;
    _mediaItems = items;
    _defaultIndex = index;
    _conversation = conversationMap != null ? IpcCodec.decodeConversation(conversationMap) : null;
  }

  /// 窗口已打开时,主窗口推来新的预览内容:整体替换并重建预览状态。
  Future<dynamic> _handleShow(dynamic args) async {
    setState(() {
      _applyPayload(args as Map<String, dynamic>);
      // 换 key 强制重建 MMPreviewView,索引/缩放/旋转全部复位
      _previewKey = GlobalKey();
    });
    // 复用已打开的窗口时,窗口也要跟着换成新媒体的形状(否则一直停在开窗
    // 时那条媒体的大小上)。视频尺寸此时未知,等播放器初始化后再调。
    _onCurrentMediaChanged(
      _defaultIndex < _mediaItems.length ? _mediaItems[_defaultIndex] : null,
      null,
    );
    return null;
  }

  // ---------------------------------------------------------- 窗口自适应尺寸

  /// 当前预览项变化:把窗口调成这条媒体的形状(尺寸策略见
  /// [MediaPreviewWindowSize])。[naturalSize] 是播放器解析出的视频真实尺寸,
  /// 为空则取消息自带的宽高(图片);都拿不到就维持当前窗口大小不动。
  void _onCurrentMediaChanged(Message? message, Size? naturalSize) {
    final Size? media = naturalSize ?? MediaPreviewWindowSize.mediaSize(message);
    if (media == null) {
      // 视频要等播放器初始化,期间别把窗口先弹成默认大小(会多跳一次)
      _resizeTimer?.cancel();
      _wantedWindowSize = null;
      return;
    }
    _requestWindowSize(MediaPreviewWindowSize.forMedia(media));
  }

  /// 连续按方向键翻页时合并成一次 resize,窗口不至于跟着一页一页地抖。
  void _requestWindowSize(Size size) {
    _wantedWindowSize = size;
    _resizeTimer?.cancel();
    _resizeTimer =
        Timer(const Duration(milliseconds: 120), _applyWantedWindowSize);
  }

  Future<void> _applyWantedWindowSize() async {
    final Size? size = _wantedWindowSize;
    if (size == null || !mounted) return;
    // window_manager 未就绪时先留着,applyWindowStyle 里会补做
    if (!windowManagerReady) return;
    if (_resizing) {
      // 上一次还没做完,稍后再试(避免 getBounds/setBounds 交叉打架)
      _requestWindowSize(size);
      return;
    }
    _resizing = true;
    try {
      // 用户自己最大化/全屏了就别再动窗口
      if (await windowManager.isMaximized() ||
          await windowManager.isFullScreen()) {
        return;
      }
      final Rect bounds = await windowManager.getBounds();
      if ((bounds.width - size.width).abs() < 2 &&
          (bounds.height - size.height).abs() < 2) {
        return;
      }
      // 以窗口中心为锚点缩放,视觉上不会整个窗口往右下角长
      await windowManager.setBounds(Rect.fromCenter(
        center: bounds.center,
        width: size.width,
        height: size.height,
      ));
    } catch (e) {
      debugPrint('mediaPreview resize window failed: $e');
    } finally {
      _resizing = false;
    }
  }

  /// ESC / Space / 关闭按钮 / Ctrl+W 共用的主动关窗路径:先暂停视频,
  /// 避免声音在窗口消失后还继续播放,再走基类的关窗+通知逻辑。
  @override
  Future<void> requestClose() async {
    await _previewKey.currentState?.pauseAllVideos();
    await super.requestClose();
  }

  /// 翻页到两端:请求主窗口加载该会话更多媒体消息(语义与内嵌预览一致)。
  Future<void> _loadMore(int fromMessageId, bool tail) async {
    final conversation = _conversation;
    if (conversation == null) return;
    final result = await WindowEventChannel.invoke<List<dynamic>>(
      0,
      MediaPreviewEvents.loadMore,
      {
        'conversation': IpcCodec.encodeConversation(conversation),
        'fromMessageId': fromMessageId,
        'tail': tail,
      },
    );
    if (result == null || result.isEmpty) return;
    final more = MediaPreviewCodec.decodeMessages(result);
    if (more.isEmpty) return;
    _previewKey.currentState?.onLoadMore(more, !tail);
  }
}
