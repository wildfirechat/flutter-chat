import 'package:desktop_multi_window/desktop_multi_window.dart';
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
  static const String _tag = 'MediaPreviewWindowApp';

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey();
  GlobalKey<MMPreviewViewState> _previewKey = GlobalKey();
  List<Message> _mediaItems = [];
  int _defaultIndex = 0;
  Conversation? _conversation;

  @override
  void initState() {
    super.initState();
    // 桌面端 showToast 依附 Navigator 的 Overlay(另存为的结果提示)。
    setToastNavigatorKey(_navigatorKey);
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
              onClose: _close,
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
    return null;
  }

  /// ESC / 关闭按钮触发的主动关窗。
  Future<void> _close() async {
    await WindowEventChannel.invoke(0, MediaPreviewEvents.windowClosed, {
      'windowId': windowId,
    });
    // 不能走 windowManager.close():若 ensureInitialized 尚未执行,macOS 侧
    // close 会因 _mainWindow 为 nil 强解包直接崩溃进程。WindowController 走
    // desktop_multi_window 自己的通道,不依赖 window_manager 的初始化状态。
    try {
      await WindowController.fromWindowId(windowId).close();
    } catch (e) {
      debugPrint('$_tag close window failed: $e');
    }
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
