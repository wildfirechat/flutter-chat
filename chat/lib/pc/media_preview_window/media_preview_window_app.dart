import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../conversation/mm_preview_view.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/show_toast.dart';
import '../../viewmodel/font_size_view_model.dart';
import '../../viewmodel/locale_view_model.dart';
import '../../viewmodel/theme_view_model.dart';
import '../multi_window/ipc_codec.dart';
import '../multi_window/window_event_channel.dart';
import 'media_preview_ipc.dart';

/// 媒体预览窗口的入口 Widget(参考微信:图片/视频在独立窗口中查看)。
///
/// 运行在独立的 Flutter Engine / Dart isolate 中,不连接 IM;
/// 翻页加载更多媒体通过 [WindowEventChannel] 请求主窗口代查。
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

class _MediaPreviewWindowAppState extends State<MediaPreviewWindowApp> with WindowListener {
  static const String _tag = 'MediaPreviewWindowApp';

  late final FontSizeViewModel _fontSizeViewModel;
  late final ThemeViewModel _themeViewModel;
  late final LocaleViewModel _localeViewModel;

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey();
  GlobalKey<MMPreviewViewState> _previewKey = GlobalKey();
  List<Message> _mediaItems = [];
  int _defaultIndex = 0;
  Conversation? _conversation;

  bool _postFirstFrameInitDone = false;

  @override
  void initState() {
    super.initState();
    // 与 Call 窗口一致:子窗口不走主窗口的插件注册时机,先同步建 ViewModel
    // 保证首帧可用,首帧后再加载持久化配置。
    _fontSizeViewModel = FontSizeViewModel(autoLoad: false);
    _themeViewModel = ThemeViewModel();
    _localeViewModel = LocaleViewModel(autoLoad: false);

    // 桌面端 showToast 依附 Navigator 的 Overlay(另存为的结果提示)。
    setToastNavigatorKey(_navigatorKey);

    _applyPayload(widget.arguments);

    final channel = WindowEventChannel();
    channel.register(MediaPreviewEvents.show, _handleShow);
    channel.listen();
    WindowEventChannel.invoke(0, MediaPreviewEvents.ready, {'windowId': widget.windowId});

    WidgetsBinding.instance.addPostFrameCallback((_) => _postFirstFrameInit());
    // 兜底:帧调度异常时 postFrameCallback 可能迟迟不来(参见 SubWindowWidgetsBinding),
    // 但 onWindowClose 监听、窗口标题都依赖 window_manager 完成初始化。
    Future.delayed(const Duration(seconds: 1), _postFirstFrameInit);
  }

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

  void _postFirstFrameInit() {
    if (_postFirstFrameInitDone) return;
    _postFirstFrameInitDone = true;
    _initWindowManager();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      await _themeViewModel.load();
      await _fontSizeViewModel.load();
      await _localeViewModel.load();
    } catch (e) {
      print('$_tag load preferences failed: $e');
    }
  }

  Future<void> _initWindowManager() async {
    try {
      // 多等一帧,确保 AppKit 已完成窗口/视图的挂载。
      await Future.delayed(const Duration(milliseconds: 50));
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      await windowManager.waitUntilReadyToShow();
      await windowManager.setTitle(_windowTitle());
      await windowManager.setMinimumSize(const Size(640, 480));
      await windowManager.show();
      await windowManager.focus();
    } catch (e, s) {
      print('$_tag windowManager init error: $e\n$s');
    }
  }

  /// 子窗口没有挂在 MaterialApp 下的 context 可用,按当前语言设置直接解析 l10n。
  String _windowTitle() {
    final locale = basicLocaleListResolution(
      [_localeViewModel.locale ?? WidgetsBinding.instance.platformDispatcher.locale],
      AppLocalizations.supportedLocales,
    );
    return lookupAppLocalizations(locale).mediaPreviewTitle;
  }

  @override
  void onWindowClose() {
    WindowEventChannel.invoke(0, MediaPreviewEvents.windowClosed, {
      'windowId': widget.windowId,
    });
  }

  /// ESC / 关闭按钮触发的主动关窗。
  Future<void> _close() async {
    await WindowEventChannel.invoke(0, MediaPreviewEvents.windowClosed, {
      'windowId': widget.windowId,
    });
    // 不能走 windowManager.close():若 ensureInitialized 尚未执行,macOS 侧
    // close 会因 _mainWindow 为 nil 强解包直接崩溃进程。WindowController 走
    // desktop_multi_window 自己的通道,不依赖 window_manager 的初始化状态。
    try {
      await WindowController.fromWindowId(widget.windowId).close();
    } catch (e) {
      print('$_tag close window failed: $e');
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

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FontSizeViewModel>.value(value: _fontSizeViewModel),
        ChangeNotifierProvider<ThemeViewModel>.value(value: _themeViewModel),
        ChangeNotifierProvider<LocaleViewModel>.value(value: _localeViewModel),
      ],
      child: Consumer2<LocaleViewModel, FontSizeViewModel>(
        builder: (context, localeViewModel, fontSizeViewModel, _) => MaterialApp(
          navigatorKey: _navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: localeViewModel.locale,
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          builder: (context, child) {
            // 与主窗口一致:字号完全由 app 内的「字体大小」设置接管
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(fontSizeViewModel.textScaleFactor),
              ),
              child: child!,
            );
          },
          home: Scaffold(
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
          ),
        ),
      ),
    );
  }
}
