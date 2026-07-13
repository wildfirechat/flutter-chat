import 'dart:convert';
import 'dart:io';

import 'package:avenginekit/engine/avengine_callback.dart';
import 'package:avenginekit/engine/avenginekit.dart';
import 'package:avenginekit/engine/call_end_reason.dart';
import 'package:avenginekit/engine/call_session.dart';
import 'package:avenginekit/engine/call_state.dart';
import 'package:avenginekit/engine/call_state.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/imclient_method_channel.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../call/conference/conference_call_screen.dart';
import '../../call/conference/join_conference_view.dart';
import '../../call/multi_call_screen.dart';
import '../../call/voip_call_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../pc/pc_shell_view_model.dart';
import '../../viewmodel/font_size_view_model.dart';
import '../../viewmodel/locale_view_model.dart';
import '../../viewmodel/theme_view_model.dart';
import '../../viewmodel/user_view_model.dart';
import 'call_window_event_channel.dart';
import 'call_window_imclient_proxy.dart';
import 'call_window_manager.dart';

import 'voip_message_codec.dart';

/// Call 窗口的入口 Widget。
///
/// 运行在独立的 Flutter Engine / Dart isolate 中，持有真实 avenginekit，
/// 并通过 [CallWindowImclientChannel] 把 IM 调用转发给主窗口。
class CallWindowApp extends StatefulWidget {
  final int windowId;
  final Map<String, dynamic> arguments;

  const CallWindowApp({
    super.key,
    required this.windowId,
    required this.arguments,
  });

  @override
  State<CallWindowApp> createState() => _CallWindowAppState();
}

class _CallWindowAppState extends State<CallWindowApp>
    with WindowListener
    implements AVEngineCallback {
  static const String _tag = 'CallWindowApp';

  late final CallWindowImclientChannel _imclientProxy;
  late final CallWindowEventChannel _eventChannel;
  late final FontSizeViewModel _fontSizeViewModel;
  late final ThemeViewModel _themeViewModel;
  late final PCShellViewModel _shellViewModel;
  late final UserViewModel _userViewModel;
  late final LocaleViewModel _localeViewModel;
  CallSession? _currentSession;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    // 先同步创建 ViewModel 实例，确保 build 在 _init 完成前也能读到非 null 的 provider。
    _initViewModels();
    _init();
  }

  void _initViewModels() {
    // Call 窗口不直接连接 IM，也不走主窗口的 SharedPreferences 插件。
    // 先不自动加载持久化配置，避免子窗口插件注册时机问题；首帧后再尝试加载。
    _fontSizeViewModel = FontSizeViewModel(autoLoad: false);
    _themeViewModel = ThemeViewModel();
    _shellViewModel = PCShellViewModel();
    _userViewModel = UserViewModel();
    _localeViewModel = LocaleViewModel(autoLoad: false);
  }

  Future<void> _init() async {
    try {
      print('$_tag _init start, windowId=${widget.windowId}, args=${widget.arguments}');

      // 设置当前用户 ID，因为 Call 窗口 isolate 中 Imclient 没有自己连接 IM。
      final selfUserId = widget.arguments['_selfUserId'] as String? ?? '';
      print('$_tag selfUserId=$selfUserId');
      ImclientPlatform.instance.userId = selfUserId;

      // 1. 替换 IM 通道为代理通道。
      _imclientProxy = CallWindowImclientChannel();
      ImclientPlatform.instance.channel = _imclientProxy;
      print('$_tag channel replaced');

      // 2. 监听主窗口转发来的事件。
      _eventChannel = CallWindowEventChannel(widget.windowId);
      _eventChannel.register(CallWindowEvents.message, _handleMessage);
      _eventChannel.register(CallWindowEvents.conferenceEvent, _handleConferenceEvent);
      _eventChannel.register(CallWindowEvents.connectionStatus, _handleConnectionStatus);
      _eventChannel.register(CallWindowEvents.startCall, _handleStartCall);
      _eventChannel.register(CallWindowEvents.startConference, _handleStartConference);
      _eventChannel.register(CallWindowEvents.joinConference, _handleJoinConference);
      _eventChannel.listen();
      print('$_tag event channel ready');

      // 3. 初始化 avenginekit（不依赖窗口可见性）。
      print('$_tag init avenginekit');
      avEngineKit.init(this);
      print('$_tag avenginekit inited');

      // 4. 通知主窗口 Call 窗口已就绪。
      print('$_tag notify main window ready');
      await CallWindowEventChannel.invoke(
        0,
        MainWindowEvents.voipStatusChanged,
        {'status': 'ready', 'windowId': widget.windowId},
      );
      print('$_tag ready notified');

      setState(() {
        _isReady = true;
      });

      // 5. 延迟初始化 window_manager 并尝试加载持久化配置。
      //    必须在窗口已显示、FlutterView 已挂载到 NSWindow 之后进行，
      //    否则 window_manager.ensureInitialized() 在 macOS 上会因
      //    registrar.view?.window 为 nil 而崩溃。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initWindowManager();
        _loadPreferences();
      });
    } catch (e, s) {
      print('$_tag _init error: $e\n$s');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      await _themeViewModel.load();
      await _fontSizeViewModel.load();
      await _localeViewModel.load();
      print('$_tag preferences loaded');
    } catch (e, s) {
      print('$_tag load preferences failed: $e');
    }
  }

  Future<void> _initWindowManager() async {
    try {
      // 多等一帧，确保 AppKit 已完成窗口/视图的挂载。
      await Future.delayed(const Duration(milliseconds: 50));
      print('$_tag ensure windowManager initialized');
      await windowManager.ensureInitialized();
      print('$_tag windowManager initialized');
      windowManager.addListener(this);
      final windowType = CallWindowManager.instance.parseWindowType(
        widget.arguments['_windowType'] as String? ?? 'single',
      );
      print('$_tag apply window style $windowType');
      await _applyWindowStyle(windowType);
      print('$_tag window style applied');
    } catch (e, s) {
      print('$_tag windowManager init error: $e\n$s');
    }
  }

  Future<void> _applyWindowStyle(CallWindowType type) async {
    print('$_tag waitUntilReadyToShow');
    await windowManager.waitUntilReadyToShow();
    print('$_tag waitUntilReadyToShow done');

    if (type == CallWindowType.conference) {
      print('$_tag set conference style');
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setBackgroundColor(Colors.transparent);
    }

    print('$_tag setMinimumSize and show');
    await windowManager.setMinimumSize(const Size(320, 480));
    await windowManager.show();
    await windowManager.focus();
    print('$_tag show done');
  }

  //region 主窗口事件处理

  Future<dynamic> _handleMessage(dynamic args) async {
    final msg = _messageFromJson(args as Map<String, dynamic>);
    avEngineKit.onReceiveMessages([msg], false);
    return null;
  }

  Future<dynamic> _handleConferenceEvent(dynamic args) async {
    avEngineKit.onConferenceEvent(args as String);
    return null;
  }

  Future<dynamic> _handleConnectionStatus(dynamic args) async {
    _imclientProxy.dispatchMethodCall('connectionStatusChanged', args);
    return null;
  }

  Future<dynamic> _handleStartCall(dynamic args) async {
    final conversation = _conversationFromJson(args['conversation'] as Map<String, dynamic>);
    final participants = (args['participants'] as List).cast<String>();
    final audioOnly = args['audioOnly'] as bool;
    final callExtra = args['callExtra'] as String? ?? '';

    avEngineKit.startCall(conversation, participants, audioOnly, callExtra: callExtra);
    return null;
  }

  Future<dynamic> _handleStartConference(dynamic args) async {
    avEngineKit.startConference(
      args['callId'] as String,
      args['audioOnly'] as bool,
      args['pin'] as String? ?? '',
      args['host'] as String,
      args['title'] as String,
      args['desc'] as String? ?? '',
      args['audience'] as bool? ?? false,
      args['advance'] as bool? ?? false,
      args['record'] as bool? ?? false,
      args['extra'] as String? ?? '',
      args['callExtra'] as String? ?? '',
      muteAudio: args['muteAudio'] as bool? ?? false,
      muteVideo: args['muteVideo'] as bool? ?? false,
    );
    return null;
  }

  Future<dynamic> _handleJoinConference(dynamic args) async {
    avEngineKit.joinConference(
      args['callId'] as String,
      args['audioOnly'] as bool,
      args['pin'] as String? ?? '',
      args['host'] as String,
      args['title'] as String,
      args['desc'] as String? ?? '',
      args['audience'] as bool? ?? false,
      args['advance'] as bool? ?? false,
      args['muteAudio'] as bool? ?? false,
      args['muteVideo'] as bool? ?? false,
      args['extra'] as String? ?? '',
      args['callExtra'] as String? ?? '',
    );
    return null;
  }

  //endregion

  @override
  void onWindowClose() async {
    // 先结束通话，再通知主窗口关闭。
    if (avEngineKit.currentSession != null && avEngineKit.currentSession!.status != CallState.STATUS_IDLE) {
      avEngineKit.currentSession!.hangup();
    }
    await CallWindowEventChannel.invoke(0, MainWindowEvents.windowClosed, {
      'windowId': widget.windowId,
    });
  }

  //region AVEngineCallback

  @override
  void onReceiveCall(CallSession session) {
    _shellViewModel.startCallSession(session);
    setState(() {
      _currentSession = session;
    });
  }

  @override
  void onStartCall(CallSession session) {
    _shellViewModel.startCallSession(session);
    setState(() {
      _currentSession = session;
    });
  }

  @override
  void shouldStartRing(bool isIncoming) {}

  @override
  void shouldStopRing() {}

  @override
  void didCallEnded(CallEndReason reason, int duration) {
    _shellViewModel.endCallSession();
    _notifyStatusChanged('ended', {'reason': reason.index, 'duration': duration});
    Future.delayed(const Duration(milliseconds: 500), () {
      _closeWindow();
    });
  }

  @override
  void onJoinConference(CallSession session) {
    _shellViewModel.startCallSession(session);
    setState(() {
      _currentSession = session;
    });
  }

  //endregion

  void _notifyStatusChanged(String status, Map<String, dynamic> extra) {
    CallWindowEventChannel.invoke(0, MainWindowEvents.voipStatusChanged, {
      'status': status,
      ...extra,
    });
  }

  Future<void> _closeWindow() async {
    await CallWindowEventChannel.invoke(0, MainWindowEvents.windowClosed, {
      'windowId': widget.windowId,
    });
    try {
      await windowManager.close();
    } catch (e) {
      // window_manager 初始化失败时回退到 WindowController。
      await WindowController.fromWindowId(widget.windowId).close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FontSizeViewModel>.value(value: _fontSizeViewModel),
        ChangeNotifierProvider<ThemeViewModel>.value(value: _themeViewModel),
        ChangeNotifierProvider<PCShellViewModel>.value(value: _shellViewModel),
        ChangeNotifierProvider<UserViewModel>.value(value: _userViewModel),
        ChangeNotifierProvider<LocaleViewModel>.value(value: _localeViewModel),
      ],
      child: _buildMaterialApp(),
    );
  }

  Widget _buildMaterialApp() {
    if (!_isReady || _currentSession == null) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: _localeViewModel.locale,
        theme: ThemeData.dark(),
        darkTheme: ThemeData.dark(),
        themeMode: _themeViewModel.themeMode,
        home: const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    final session = _currentSession!;
    Widget screen;
    if (session.conference) {
      screen = ConferenceCallScreen(session: session);
    } else if (session.conversation?.conversationType == ConversationType.Group) {
      screen = MultiCallScreen(session: session);
    } else {
      screen = VoipCallScreen(session: session);
    }

    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _localeViewModel.locale,
      theme: ThemeData.dark(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeViewModel.themeMode,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: screen,
      ),
    );
  }

  Message _messageFromJson(Map<String, dynamic> json) {
    return VoipMessageCodec.decodeMessage(json);
  }

  Conversation _conversationFromJson(Map<String, dynamic> json) {
    return Conversation(
      conversationType: ConversationType.values[json['conversationType'] as int],
      target: json['target'] as String,
      line: json['line'] as int? ?? 0,
    );
  }
}
