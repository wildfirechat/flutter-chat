import 'package:avenginekit/engine/avengine_callback.dart';
import 'package:avenginekit/engine/avenginekit.dart';
import 'package:avenginekit/engine/call_end_reason.dart';
import 'package:avenginekit/engine/call_session.dart';
import 'package:avenginekit/engine/call_state.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:window_manager/window_manager.dart';

import '../../call/conference/conference_call_screen.dart';
import '../../call/multi_call_screen.dart';
import '../../call/voip_call_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../pc/pc_shell_view_model.dart';
import '../../viewmodel/user_view_model.dart';
import '../multi_window/ipc_codec.dart';
import '../multi_window/sub_window_app_base.dart';
import '../multi_window/window_event_channel.dart';
import 'call_window_events.dart';
import 'call_window_manager.dart';
import 'voip_message_codec.dart';

/// Call 窗口的入口 Widget。
///
/// 运行在独立的 Flutter Engine / Dart isolate 中，持有真实 avenginekit，
/// 并通过基类装配的 [SharedImclientChannel] 把 IM 调用转发给主窗口。
/// 窗口初始化/标题/主题/关窗通知等样板见 [SubWindowAppBase];
/// 就绪/关窗事件名与窗口样式分支是本窗口特有的,走基类覆写口。
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
    with WindowListener, SubWindowAppBase<CallWindowApp>
    implements AVEngineCallback {
  static const String _tag = 'CallWindowApp';

  // 先同步创建 ViewModel 实例，确保 build 在 init 完成前也能读到非 null 的 provider。
  // Call 窗口不直接连接 IM，也不走主窗口的 SharedPreferences 插件。
  final PCShellViewModel _shellViewModel = PCShellViewModel();
  final UserViewModel _userViewModel = UserViewModel();

  CallSession? _currentSession;

  // -------------------------------------------------------------- 基类钩子

  @override
  int get windowId => widget.windowId;

  @override
  Map<String, dynamic> get windowArguments => widget.arguments;

  @override
  String get windowKind => 'call';

  @override
  Size get minWindowSize => const Size(320, 480);

  /// 通话窗没有独立的"关闭"语义,只能挂断结束通话(见 [_closeWindow] 的
  /// 调用点),Ctrl/Cmd+W 不应绕过挂断直接关窗。
  @override
  bool get closableByShortcut => false;

  /// 通话窗是黑色全屏界面,亮暗主题都强制 dark(themeMode 跟随设置,
  /// 两个主题相同,效果与原来一致)。
  @override
  ThemeData buildLightTheme() => ThemeData.dark();
  @override
  ThemeData buildDarkTheme() => ThemeData.dark();

  @override
  List<SingleChildWidget> get extraProviders => [
        ChangeNotifierProvider<PCShellViewModel>.value(value: _shellViewModel),
        ChangeNotifierProvider<UserViewModel>.value(value: _userViewModel),
      ];

  @override
  Map<String, Future<dynamic> Function(dynamic)> get eventHandlers => {
        CallWindowEvents.message: _handleMessage,
        CallWindowEvents.conferenceEvent: _handleConferenceEvent,
        CallWindowEvents.connectionStatus: _handleConnectionStatus,
        CallWindowEvents.startCall: _handleStartCall,
        CallWindowEvents.startConference: _handleStartConference,
        CallWindowEvents.joinConference: _handleJoinConference,
      };

  CallWindowType get _windowType => CallWindowManager.instance
      .parseWindowType(windowArguments['_windowType'] as String? ?? 'single');

  @override
  String windowTitle(AppLocalizations l10n) {
    switch (_windowType) {
      case CallWindowType.single:
        return l10n.audioVideoCall;
      case CallWindowType.multi:
        return l10n.multiCallWindowTitle;
      case CallWindowType.conference:
        return l10n.conferenceTitle;
    }
  }

  /// 初始化 avenginekit（不依赖窗口可见性）,完成后基类再发就绪通知。
  @override
  Future<void> onWindowReady() async {
    debugPrint('$_tag init avenginekit');
    avEngineKit.init(this);
  }

  /// 就绪通知不走 '<kind>.ready':主窗口等的是 voipStatusChanged{status:'ready'}。
  @override
  Future<void> notifyReady() async {
    await WindowEventChannel.invoke(
      0,
      MainWindowEvents.voipStatusChanged,
      {'status': 'ready', 'windowId': windowId},
    );
  }

  /// 通话窗口样式分支:会议窗隐藏标题栏 + 透明背景。
  @override
  Future<void> applyWindowStyle() async {
    await updateWindowTitle();
    if (_windowType == CallWindowType.conference) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setBackgroundColor(Colors.transparent);
    }
    await windowManager.setMinimumSize(minWindowSize);
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Widget buildLoading(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  @override
  Widget buildHome(BuildContext context) {
    final session = _currentSession;
    if (session == null) {
      // 已就绪但通话尚未发起(等主窗口 startCall 等事件),保持黑屏加载页。
      return buildLoading(context);
    }
    Widget screen;
    if (session.conference) {
      screen = ConferenceCallScreen(session: session);
    } else if (session.conversation?.conversationType ==
        ConversationType.Group) {
      screen = MultiCallScreen(session: session);
    } else {
      screen = VoipCallScreen(session: session);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: screen,
    );
  }

  //region 主窗口事件处理

  // 主窗口转发来的事件统一 fire 到本 isolate 的 IMEventBus,与移动端的事件分发
  // 保持同构:avenginekit(init 时已订阅)、ConferenceManager 等所有订阅者都能收到,
  // 而不是只有 avenginekit 一家(直调 avEngineKit 会让其它总线订阅者收不到消息)。

  Future<dynamic> _handleMessage(dynamic args) async {
    final msg = _messageFromJson(args as Map<String, dynamic>);
    Imclient.IMEventBus.fire(ReceiveMessagesEvent([msg], false));
    return null;
  }

  Future<dynamic> _handleConferenceEvent(dynamic args) async {
    Imclient.IMEventBus.fire(ConferenceEvent(args as String));
    return null;
  }

  Future<dynamic> _handleConnectionStatus(dynamic args) async {
    Imclient.IMEventBus.fire(ConnectionStatusChangedEvent(args as int));
    return null;
  }

  Future<dynamic> _handleStartCall(dynamic args) async {
    final conversation = IpcCodec.decodeConversation(
        args['conversation'] as Map<String, dynamic>);
    final participants = (args['participants'] as List).cast<String>();
    final audioOnly = args['audioOnly'] as bool;
    final callExtra = args['callExtra'] as String? ?? '';

    avEngineKit.startCall(conversation, participants, audioOnly,
        callExtra: callExtra);
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
    if (avEngineKit.currentSession != null &&
        avEngineKit.currentSession!.status != CallState.STATUS_IDLE) {
      avEngineKit.currentSession!.hangup();
    }
    await WindowEventChannel.invoke(0, MainWindowEvents.windowClosed, {
      'windowId': windowId,
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
    _notifyStatusChanged(
        'ended', {'reason': reason.index, 'duration': duration});
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
    WindowEventChannel.invoke(0, MainWindowEvents.voipStatusChanged, {
      'status': status,
      ...extra,
    });
  }

  Future<void> _closeWindow() async {
    await WindowEventChannel.invoke(0, MainWindowEvents.windowClosed, {
      'windowId': windowId,
    });
    // 不能走 windowManager.close()：若 ensureInitialized 尚未执行（帧被冻结
    // 等场景），macOS 侧 close 会因 _mainWindow 为 nil 强解包直接崩溃进程，
    // Dart 的 try/catch 捕不住。WindowController 走 desktop_multi_window
    // 自己的通道，不依赖 window_manager 的初始化状态。
    try {
      await WindowController.fromWindowId(windowId).close();
    } catch (e) {
      debugPrint('$_tag close window failed: $e');
    }
  }

  Message _messageFromJson(Map<String, dynamic> json) {
    return VoipMessageCodec.decodeMessage(json);
  }
}
