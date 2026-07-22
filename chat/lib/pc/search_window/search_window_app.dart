import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/imclient_method_channel.dart';
import 'package:imclient/message/articles_message_content.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:imclient/message/collection_message_content.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/link_message_content.dart';
import 'package:imclient/message/location_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/notification/recall_notificiation_content.dart';
import 'package:imclient/message/notification/tip_notificiation_content.dart';
import 'package:imclient/message/poll_message_content.dart';
import 'package:imclient/message/ptext_message_content.dart';
import 'package:imclient/message/rich_notification_message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/sticker_message_content.dart';
import 'package:imclient/message/streaming_text_generated_message_content.dart';
import 'package:imclient/message/streaming_text_generating_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../search/conversation_search_panel.dart';
import '../../viewmodel/font_size_view_model.dart';
import '../../viewmodel/locale_view_model.dart';
import '../../viewmodel/theme_view_model.dart';
import '../multi_window/ipc_codec.dart';
import '../multi_window/window_event_channel.dart';
import 'search_window_imclient_channel.dart';
import 'search_window_ipc.dart';

/// 会话内搜索窗口的入口 Widget（类似 PC 微信的"聊天记录"窗口）。
///
/// 运行在独立的 Flutter Engine / Dart isolate 中，不连接 IM；
/// IM 调用经 [SearchWindowImclientChannel] 转发到主窗口执行，
/// 与朋友圈窗口（MomentWindowApp）同构。
class SearchWindowApp extends StatefulWidget {
  final int windowId;
  final Map<String, dynamic> arguments;

  const SearchWindowApp({
    super.key,
    required this.windowId,
    required this.arguments,
  });

  @override
  State<SearchWindowApp> createState() => _SearchWindowAppState();
}

class _SearchWindowAppState extends State<SearchWindowApp> with WindowListener {
  static const String _tag = 'SearchWindowApp';

  late final FontSizeViewModel _fontSizeViewModel;
  late final ThemeViewModel _themeViewModel;
  late final LocaleViewModel _localeViewModel;

  late Conversation _conversation;
  String _conversationTitle = '';
  String _keyword = '';

  /// 切换会话时换 key 强制重建面板，清空旧的搜索状态。
  Key _panelKey = UniqueKey();

  bool _isReady = false;

  /// window_manager 是否已完成 ensureInitialized。子窗口里任何
  /// windowManager 调用都必须排在其后，否则 macOS 原生侧
  /// WindowManager.mainWindow 还是 nil，强解包直接崩溃（Swift fatal
  /// error 无法被 Dart try/catch 捕获）。
  bool _windowManagerInited = false;

  @override
  void initState() {
    super.initState();
    _fontSizeViewModel = FontSizeViewModel(autoLoad: false);
    _themeViewModel = ThemeViewModel();
    _localeViewModel = LocaleViewModel(autoLoad: false);
    _init();
  }

  Future<void> _init() async {
    try {
      debugPrint('$_tag _init start, windowId=${widget.windowId}');

      _conversation = SearchWindowPayload.decodeConversation(widget.arguments);
      _conversationTitle = SearchWindowPayload.decodeTitle(widget.arguments);
      _keyword = SearchWindowPayload.decodeKeyword(widget.arguments);
      _panelKey = _buildPanelKey(_conversation);

      // 搜索窗口 isolate 中 Imclient 没有自己连接 IM，先设置当前用户。
      final selfUserId = widget.arguments['_selfUserId'] as String? ?? '';
      ImclientPlatform.instance.userId = selfUserId;

      // 1. 替换 IM 通道为代理通道。
      ImclientPlatform.instance.channel = SearchWindowImclientChannel();

      // 2. 注册常用消息内容类型（仅 Dart 层解码用，digest 依赖具体类型）。
      _registerMessageContents();

      // 3. 监听主窗口转发来的事件。
      final channel = WindowEventChannel();
      channel.register(
          SearchWindowEvents.updateConversation, _handleUpdateConversation);
      channel.listen();

      // 4. 通知主窗口已就绪。
      await WindowEventChannel.invoke(0, SearchWindowEvents.ready, {
        'windowId': widget.windowId,
      });

      setState(() => _isReady = true);

      // 与朋友圈/Call 窗口一致：window_manager 延迟到首帧后初始化。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _postFirstFrameInit();
      });
      Future.delayed(const Duration(seconds: 1), _postFirstFrameInit);
    } catch (e, s) {
      debugPrint('$_tag _init error: $e\n$s');
    }
  }

  /// 与 Imclient.init 注册的常用类型对齐；未注册的类型解码成
  /// UnknownMessageContent，摘要只会显示"未知消息"。
  void _registerMessageContents() {
    Imclient.registerMessageContent(textContentMeta);
    Imclient.registerMessageContent(imageContentMeta);
    Imclient.registerMessageContent(videoContentMeta);
    Imclient.registerMessageContent(soundContentMeta);
    Imclient.registerMessageContent(fileContentMeta);
    Imclient.registerMessageContent(linkContentMeta);
    Imclient.registerMessageContent(stickerContentMeta);
    Imclient.registerMessageContent(locationMessageContentMeta);
    Imclient.registerMessageContent(cardContentMeta);
    Imclient.registerMessageContent(compositeContentMeta);
    Imclient.registerMessageContent(ptextContentMeta);
    Imclient.registerMessageContent(articlesContentMeta);
    Imclient.registerMessageContent(callStartContentMeta);
    Imclient.registerMessageContent(collectionContentMeta);
    Imclient.registerMessageContent(pollContentMeta);
    Imclient.registerMessageContent(richNotificationContentMeta);
    Imclient.registerMessageContent(recallNotificationContentMeta);
    Imclient.registerMessageContent(tipNotificationContentMeta);
    Imclient.registerMessageContent(streamingTextGeneratingContentMeta);
    Imclient.registerMessageContent(streamingTextGeneratedContentMeta);
  }

  bool _postFirstFrameInitDone = false;

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
      // 语言设置加载完成后按最终语言刷新一次标题。
      await _updateWindowTitle();
    } catch (e) {
      debugPrint('$_tag load preferences failed: $e');
    }
  }

  Future<void> _initWindowManager() async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));
      await windowManager.ensureInitialized();
      _windowManagerInited = true;
      windowManager.addListener(this);
      await windowManager.waitUntilReadyToShow();
      // desktop_multi_window 创建的 macOS 子窗口默认隐藏标题栏
      // (fullSizeContentView + titleVisibility=.hidden)，恢复为标准标题栏，
      // 显示 `"会话名"聊天记录` 标题（对齐 PC 微信）。
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await _updateWindowTitle();
      await windowManager.setMinimumSize(const Size(480, 600));
      await windowManager.show();
      await windowManager.focus();
    } catch (e, s) {
      debugPrint('$_tag windowManager init error: $e\n$s');
    }
  }

  /// 窗口标题 `"<会话名>"<chatRecords>`；子窗口没有挂在 MaterialApp 下的
  /// context 可用，按当前语言设置直接解析 l10n（同媒体预览窗口）。
  Future<void> _updateWindowTitle() async {
    // 与 _loadPreferences 存在并发：偏好加载可能先于 window_manager
    // 初始化完成，此时不得触碰 windowManager（见 _windowManagerInited 注释）。
    if (!_windowManagerInited) return;
    final locale = basicLocaleListResolution(
      [
        _localeViewModel.locale ??
            WidgetsBinding.instance.platformDispatcher.locale
      ],
      AppLocalizations.supportedLocales,
    );
    final title =
        '"$_conversationTitle"${lookupAppLocalizations(locale).chatRecords}';
    try {
      await windowManager.setTitle(title);
    } catch (e) {
      debugPrint('$_tag setTitle failed: $e');
    }
  }

  /// 窗口复用时主窗口推来新的搜索目标：整体替换并重建面板状态。
  Future<dynamic> _handleUpdateConversation(dynamic args) async {
    if (args is! Map) return null;
    setState(() {
      _conversation = SearchWindowPayload.decodeConversation(args);
      _conversationTitle = SearchWindowPayload.decodeTitle(args);
      _keyword = SearchWindowPayload.decodeKeyword(args);
      _panelKey = _buildPanelKey(_conversation);
    });
    _updateWindowTitle();
    return null;
  }

  Key _buildPanelKey(Conversation conversation) {
    return ValueKey(
        'search-${conversation.conversationType.index}-${conversation.target}-${conversation.line}');
  }

  /// 点击搜索结果：转发给主窗口，由主窗口打开会话并定位消息。
  void _locateMessage(Message message) {
    WindowEventChannel.invoke(0, SearchWindowEvents.locateMessage, {
      'conversation': IpcCodec.encodeConversation(message.conversation),
      'messageId': message.messageId,
    });
  }

  @override
  void onWindowClose() async {
    await WindowEventChannel.invoke(0, SearchWindowEvents.windowClosed, {
      'windowId': widget.windowId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FontSizeViewModel>.value(
            value: _fontSizeViewModel),
        ChangeNotifierProvider<ThemeViewModel>.value(value: _themeViewModel),
        ChangeNotifierProvider<LocaleViewModel>.value(value: _localeViewModel),
      ],
      child: Consumer2<LocaleViewModel, FontSizeViewModel>(
        builder: (context, localeViewModel, fontSizeViewModel, _) {
          return MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: localeViewModel.locale,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _themeViewModel.themeMode,
            builder: (context, child) {
              // 与主窗口一致：字号完全由 app 内的「字体大小」设置接管
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler:
                      TextScaler.linear(fontSizeViewModel.textScaleFactor),
                ),
                child: child!,
              );
            },
            home: Scaffold(
              body: SafeArea(
                child: _isReady
                    ? ConversationSearchPanel(
                        _conversation,
                        key: _panelKey,
                        initialKeyword: _keyword,
                        showSearchHistory: false,
                        onLocateMessage: _locateMessage,
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        },
      ),
    );
  }
}
