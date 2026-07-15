import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:avenginekit/engine/call_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/read_report.dart';
import 'package:imclient/model/user_info.dart';
import 'package:imclient/model/user_online_state.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:avenginekit/engine/avengine_callback.dart';
import 'package:avenginekit/engine/call_session.dart';
import 'package:avenginekit/engine/call_end_reason.dart';
import 'package:avenginekit/engine/avenginekit.dart';
import 'package:chat/call/callkit_service.dart';
import 'package:chat/call/voip_call_screen.dart';
import 'package:chat/call/multi_call_screen.dart';
import 'package:chat/call/conference/conference_call_screen.dart';
import 'package:chat/share/share_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/pc_shell_view_model.dart';

// import 'package:momentclient/momentclient.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat/splash.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/contact_list_view_model.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/viewmodel/locale_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/viewmodel/font_size_view_model.dart';
import 'package:chat/viewmodel/theme_view_model.dart';
import 'package:chat/wfc_notification_manager.dart';

import 'app_navigator.dart';
import 'app_theme.dart';
import 'config.dart';
import 'utils/media_url_redirector.dart';

import 'default_portrait_provider.dart';
import 'home/home.dart';
import 'internal/app_state.dart';
import 'login_screen.dart';
import 'pc/pc_home.dart';
import 'pc/pc_layout_view_model.dart';
import 'pc/pc_qr_login_screen.dart';
import 'pc/pc_tray_manager.dart';
import 'pc/pc_window_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/widget/watermark_overlay.dart';
import 'package:chat/mesh/mesh_cache.dart';
import 'package:chat/organization/organization_cache.dart';
import 'package:chat/organization/organization_service.dart';
import 'package:chat/pc/call_window/call_window_app.dart';
import 'package:chat/pc/call_window/call_window_binding.dart';
import 'package:chat/pc/call_window/main_avengine_kit_proxy.dart';

void main([List<String>? args]) async {
  final effectiveArgs = args ?? <String>[];

  // 子窗口入口。必须用 CallWindowWidgetsBinding 而不是默认 binding：
  // macOS 子引擎会收到错误的 hidden 生命周期状态导致帧调度被关闭。
  if (effectiveArgs.isNotEmpty && effectiveArgs[0] == 'multi_window') {
    CallWindowWidgetsBinding.ensureInitialized();
    final windowId = int.parse(effectiveArgs[1]);
    final arguments = effectiveArgs.length > 2 ? jsonDecode(effectiveArgs[2]) as Map<String, dynamic> : <String, dynamic>{};
    runApp(CallWindowApp(windowId: windowId, arguments: arguments));
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();

  // 限制全局图片内存缓存，避免大图/头像过多时内存占用过高
  PaintingBinding.instance.imageCache
    ..maximumSize = 200
    ..maximumSizeBytes = 50 << 20; // 50MB

  if (!isDesktopShell) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 状态栏/导航栏图标的明暗跟随主题,由 MyApp 里的 AnnotatedRegion 下发。
  }
  // image_picker 在 Android 上只剩"我"页拍照换头像在用,相册均已改走应用内
  // asset picker。显式赋值实例,不依赖自动注册链上的类型判断——本项目出现过
  // 插件注册链中断导致后续插件未注册的问题,届时 is 判断会静默失效
  if (Platform.isAndroid) {
    ImagePickerPlatform.instance = ImagePickerAndroid();
  }
  final PcLayoutViewModel? pcLayoutViewModel = isDesktopShell ? PcLayoutViewModel() : null;
  if (isDesktopShell) {
    await PCWindowManager().ensureInitialized();
    // 首帧之前读出上次的栏宽/输入栏高度,避免默认尺寸闪一下再跳
    await pcLayoutViewModel!.load();
  }
  // 同理,首帧之前读出明暗设置,否则暗色用户开屏会先闪一帧浅色
  final themeViewModel = ThemeViewModel();
  await themeViewModel.load();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<UserViewModel>(create: (_) => UserViewModel()),
      ChangeNotifierProvider<GroupViewModel>(create: (_) => GroupViewModel()),
      ChangeNotifierProvider<ChannelViewModel>(create: (_) => ChannelViewModel()),
      ChangeNotifierProvider<ConversationViewModel>(create: (_) => ConversationViewModel()),
      ChangeNotifierProvider<ConversationListViewModel>(create: (_) => ConversationListViewModel()),
      ChangeNotifierProvider<ContactListViewModel>(create: (_) => ContactListViewModel()),
      ChangeNotifierProvider<LocaleViewModel>(create: (_) => LocaleViewModel()),
      ChangeNotifierProvider<FontSizeViewModel>(create: (_) => FontSizeViewModel()),
      // 已在 main 中 load 完毕,用 .value 交给 Provider(应用级生命周期,不随登出销毁)
      ChangeNotifierProvider<ThemeViewModel>.value(value: themeViewModel),
      // 桌面 Shell 的导航状态。仅桌面注册:共享代码经 app_navigator.dart 查找,
      // 移动端取不到即走整页 push 路径。
      if (isDesktopShell) ChangeNotifierProvider<PCShellViewModel>(create: (_) => PCShellViewModel()),
      if (isDesktopShell) ChangeNotifierProvider<PcLayoutViewModel>.value(value: pcLayoutViewModel!),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>();
  }
}

class _MyAppState extends State<MyApp> {
  final navKey = GlobalKey<NavigatorState>();

  bool? isLogined;
  bool _isBackground = false;
  bool _firstConnected = false;
  late MainAVEngineCallback _avEngineCallback;

  /// 桌面 Shell 导航状态;移动端为 null。
  PCShellViewModel? _shell;
  Timer? _badgeRefreshTimer;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    setToastNavigatorKey(navKey);
    setPCWindowNavKey(navKey);
    if (isDesktopShell) {
      _shell = context.read<PCShellViewModel>();
      // 桌面端窗口恢复逻辑已后移到 _initIMClient 中，等登录状态判定完成后再 show/focus，
      // 避免未登录时窗口先闪到上次登录保存的位置。
      // PCWindowManager().setupWindow();
      // 桌面端没有 AppLifecycleState.paused，用窗口事件判断前后台
      pcAppInBackground.addListener(() {
        _isBackground = pcAppInBackground.value;
        if (!_isBackground) {
          updateAppBadge();
        }
      });
    }
    _initIMClient();
    _initRepo();
    CallKitService.instance.init();
    ShareService.instance.init();
    ShareService.instance.shareItemsStream.listen((items) {
      debugPrint('Received shared items: $items');
      // TODO: 展示会话选择器，把内容发送到选中的会话
    });
    WfcNotificationManager().init();
    WfcNotificationManager().onNotificationTapped = _handleNotificationTap;

    SystemChannels.lifecycle.setMessageHandler((message) async {
      final state = parseStateFromString(message!);
      WidgetsBinding.instance.handleAppLifecycleStateChanged(state);
      if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
        _isBackground = true;
        debugPrint("goto background");
        updateAppBadge();
        ShareService.instance.syncSharedDataOnBackground();
      } else if (state == AppLifecycleState.resumed) {
        debugPrint("goto foreground");
        _isBackground = false;
      }
      return message; // Ensure the message is returned as per your last working state
    });

    Imclient.IMEventBus.on<ReceiveMessagesEvent>().listen((event) {
      if (_isBackground) {
        WfcNotificationManager().handleReceiveMessage(event.messages);
      }
      // 前台也要更新托盘未读数
      updateAppBadge();
    });

    Imclient.IMEventBus.on<FriendRequestUpdateEvent>().listen((event) {
      if (_isBackground) {
        WfcNotificationManager().handleFriendRequest(event.newUserRequests);
      }
      // 好友请求也可能影响未读数,同步更新托盘
      updateAppBadge();
    });

    Imclient.IMEventBus.on<UserSettingUpdatedEvent>().listen((event) {
      // 设置更新(如静音、已读)后刷新托盘未读状态
      updateAppBadge();
    });

    Imclient.IMEventBus.on<ClearMessagesEvent>().listen((event) {
      // 清除会话消息后刷新托盘未读状态
      updateAppBadge();
    });

    Imclient.IMEventBus.on<ClearConversationUnreadEvent>().listen((event) {
      // 清除会话未读数后刷新托盘未读状态
      updateAppBadge();
    });

    Imclient.IMEventBus.on<ClearConversationsUnreadEvent>().listen((event) {
      // 清除多会话未读数后刷新托盘未读状态
      updateAppBadge();
    });

    Imclient.IMEventBus.on<MessageReadedEvent>().listen((event) {
      // 消息被已读后刷新托盘未读状态
      updateAppBadge();
    });
  }

  Future<void> _initIMClient() async {

    Imclient.setDefaultPortraitProvider(WFPortraitProvider.instance);

    await Imclient.init((int status) {
      if (kDebugMode) {
        print(status);
      }
      if (status == kConnectionStatusConnected) {
        if (!_firstConnected) {
          _firstConnected = true;
          OrganizationService.instance.login().then((_) {
            OrganizationCache.instance.loadMyOrganizationInfos();
          }).catchError((e) {
            if (kDebugMode) {
              print('Organization service login failed after IM connected: $e');
            }
          });
        }
        return;
      }
      if (status == kConnectionStatusSecretKeyMismatch ||
          status == kConnectionStatusTokenIncorrect ||
          status == kConnectionStatusRejected ||
          status == kConnectionStatusKickedOff ||
          status == kConnectionStatusLogout) {
        // 应用主动退出时会触发 logout，此时不应清除登录态。
        if (status == kConnectionStatusLogout && PCWindowManager().isQuitting) {
          return;
        }
        if (status != kConnectionStatusLogout) {
          Imclient.isLogined.then((value) {
            if (value) {
              Imclient.disconnect();
            }
          });
        }
        SharedPreferences.getInstance().then((value) {
          value.remove('userId');
          value.remove('token');
          value.remove('app_server_auth_token');
          value.commit();
          OrganizationService.instance.clearOrgServiceAuthInfos();
          OrganizationCache.instance.clearCaches();
          MeshCache.instance.clear();
          _firstConnected = false;
        });

        if (mounted) {
          context.read<UserViewModel>().reset();
          context.read<GroupViewModel>().reset();
          context.read<ChannelViewModel>().reset();
          context.read<ConversationViewModel>().reset();
          context.read<ConversationListViewModel>().reset();
          context.read<ContactListViewModel>().reset();
        }

        isLogined = false;
        if (navKey.currentState != null) {
          navigateToLogin(navKey.currentState!);
        }
      }
    }, (List<Message> messages, bool hasMore) {
      if (kDebugMode) {
        print(messages);
      }
    }, (messageUid) {
      if (kDebugMode) {
        print('recall message $messageUid');
      }
    }, (messageUid) {
      if (kDebugMode) {
        print('delete message $messageUid');
      }
    }, onConnectedCallback: (String host, String ip, int port, bool mainNetwork) {
      MediaUrlRedirector.setConnectedToMainNetwork(mainNetwork);
    }, messageDeliveriedCallback: (Map<String, int> deliveryMap) {
      if (kDebugMode) {
        print('on message deliveried $deliveryMap');
      }
    }, messageReadedCallback: (List<ReadReport> readReports) {
      if (kDebugMode) {
        print("on message readed $readReports");
      }
    }, groupInfoUpdatedCallback: (List<GroupInfo> groupInfos) {
      if (kDebugMode) {
        print("on groupInfo updated $groupInfos");
      }
    }, groupMemberUpdatedCallback: (String groupId, List<GroupMember> members) {
      if (kDebugMode) {
        print("on group $groupId member updated $members");
      }
    }, userInfoUpdatedCallback: (List<UserInfo> userInfos) {
      // for (var element in userInfos) {
      //   debugPrint(\'on \${element.userId} user info updated\');
      // }
    }, channelInfoUpdatedCallback: (List<ChannelInfo> channelInfos) {
      if (kDebugMode) {
        print("on ChannelInfo updated $channelInfos");
      }
    }, userSettingsUpdatedCallback: () {
      if (kDebugMode) {
        print("on user settings updated");
      }
      // IM SDK 回调里也要刷新,确保托盘未读数与设置同步
      updateAppBadge();
    }, friendListUpdatedCallback: (List<String> newFriendIds) {
      if (kDebugMode) {
        print("on friend list updated $newFriendIds");
      }
      if (mounted) {
        context.read<ContactListViewModel>().refresh();
      }
    }, friendRequestListUpdatedCallback: (List<String> newFriendRequests) {
      if (kDebugMode) {
        print("on friend request updated $newFriendRequests");
      }
      if (mounted) {
        context.read<ContactListViewModel>().refresh();
      }
    }, onlineEventCallback: (List<UserOnlineState> onlineInfos) {
      if (kDebugMode) {
        print(onlineInfos);
      }
    });

    // IM 初始化完成后立即安装音视频代理（桌面端通过子窗口承载，移动端直接初始化 avenginekit）。
    if (isDesktopShell) {
      MainAvEngineKitProxy.instance.install();
    } else {
      _avEngineCallback = MainAVEngineCallback(navKey, _shell);
      avEngineKit.init(_avEngineCallback);
    }

    Imclient.startLog();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await OrganizationCache.instance.initialize();
    _currentUserId = prefs.getString("userId");
    final hasCredentials = _currentUserId != null && prefs.getString("token") != null;
    if (isDesktopShell) {
      // 桌面端先判断登录状态，已登录才恢复上次窗口位置，避免未登录时窗口先闪到旧位置
      await PCWindowManager().setupWindow(restoreSavedState: hasCredentials);
    }
    if (hasCredentials) {
      Imclient.connect(Config.IM_Host, _currentUserId!, prefs.getString("token")!);
      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          isLogined = true;
        });
      });
    } else {
      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          isLogined = false;
        });
      });
    }

    // MomentClient.init((comment) {
    //   debugPrint("receive comment");
    // }, (feed){
    //   debugPrint("receive feed");
    // });
  }

  void _initRepo() {
    // TODO: 是否需要优化，预加载一些数据
  }

  void _handleNotificationTap(String payload) async {
    if (!isDesktopShell) {
      return;
    }
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>?;
      if (data == null) return;
      final type = data['type'] as String?;
      if (type == 'message') {
        final conversationTypeIndex = data['conversationType'] as int?;
        final target = data['target'] as String?;
        final line = data['line'] as int?;
        if (conversationTypeIndex == null || target == null) return;
        final conversation = Conversation(
          conversationType: ConversationType.values[conversationTypeIndex],
          target: target,
          line: line ?? 0,
        );
        await windowManager.show();
        await windowManager.focus();
        _shell?.openConversation(conversation);
      } else if (type == 'friend_request') {
        await windowManager.show();
        await windowManager.focus();
        _shell?.selectTab(PCShellViewModel.tabContact);
      }
    } catch (e) {
      debugPrint('handle notification tap failed: $e');
    }
  }

  /// 刷新未读角标。事件风暴期间(如初次同步)只在静默 300ms 后真正拉取一次。
  void updateAppBadge() {
    _badgeRefreshTimer?.cancel();
    _badgeRefreshTimer = Timer(const Duration(milliseconds: 300), _refreshAppBadge);
  }

  void _refreshAppBadge() {
    Imclient.isLogined.then((isLogined) {
      if (!isLogined) {
        return;
      }
      Imclient.getConversationInfos([ConversationType.Single, ConversationType.Group, ConversationType.Channel], [0]).then((value) {
        int unreadCount = 0;
        for (var element in value) {
          if (!element.isSilent) {
            unreadCount += element.unreadCount.unread;
          }
        }
        Imclient.getUnreadFriendRequestStatus().then((unreadFriendRequest) {
          unreadCount += unreadFriendRequest;
          _updatePlatformBadge(unreadCount);
        });
      });
    });
  }

  void _updatePlatformBadge(int count) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
//       try {
//         FlutterDynamicIcon.setApplicationIconBadgeNumber(count);
//       } catch (e) {
//         debugPrint('unsupport app icon badge number platform');
//       }
    } else if (isDesktopShell) {
      // 桌面端:Dock(macOS)/任务栏(Windows) badge 目前通过托盘角标/标题模拟
      // tray_manager 没有 setBadge API,先更新托盘 tooltip 和未读闪烁。
      PCTrayManager().updateUnreadCount(count);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<LocaleViewModel, FontSizeViewModel, ThemeViewModel>(
      builder: (context, localeViewModel, fontSizeViewModel, themeViewModel, _) {
        return MaterialApp(
          locale: localeViewModel.locale,
          builder: (context, child) {
            // 字号完全由 app 内的「字体大小」设置接管,刻意丢弃系统 textScaler
            // (与微信一致)。系统字体档位与 app 档位叠乘会放到 1.9 倍以上,
            // 现有布局撑不住;若要恢复跟随系统,需要先把固定高度全部改成约束。
            Widget content = MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(fontSizeViewModel.textScaleFactor),
              ),
              child: child!,
            );
            if (!isDesktopShell) {
              // 这里的 context 位于 MaterialApp 的 Theme 之下,themeMode 为
              // ThemeMode.system 时也能拿到系统解析后的明暗。
              content = AnnotatedRegion<SystemUiOverlayStyle>(
                value: AppTheme.systemOverlayStyle(Theme.of(context).brightness),
                child: content,
              );
            }
            return content;
          },
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''), // English, no country code
            Locale('zh', ''), // Chinese, no country code
          ],
          navigatorKey: navKey,
          home: _buildHome(),
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeViewModel.themeMode,
        );
      },
    );
  }

  void onLoginSuccess(String userId) {
    setState(() {
      _currentUserId = userId;
      isLogined = true;
    });
  }

  Widget _buildHome() {
    Widget home;
    if (isLogined == null) {
      home = const SplashScreen();
    } else if (!isLogined!) {
      home = isDesktopShell ? const PCQRLoginScreen() : const LoginScreen();
    } else {
      home = isDesktopShell ? const PCHome() : const HomeTabBar();
    }
    return Stack(
      children: [
        home,
        Positioned.fill(
          child: WatermarkOverlay(userId: _currentUserId),
        ),
      ],
    );
  }
}
class MainAVEngineCallback implements AVEngineCallback {
  final GlobalKey<NavigatorState> navKey;

  /// 桌面端注入:通话在 Shell 浮窗中展示;移动端为 null,整页 push 通话页。
  final PCShellViewModel? shell;

  MainAVEngineCallback(this.navKey, this.shell);

  @override
  void didCallEnded(CallEndReason reason, int duration) {
    debugPrint('didCallEnded: $reason, $duration');
    final session = avEngineKit.currentSession;
    if (session != null) {
      CallKitService.instance.reportCallEnded(session.callId);
    }
  }

  @override
  void onJoinConference(CallSession session) {
    debugPrint('onJoinConference: ${session.callId}');
    if (shell != null) {
      shell!.startCallSession(session);
      return;
    }
    Navigator.of(navKey.currentContext!).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => ConferenceCallScreen(session: session), settings: const RouteSettings(name: "conferenceCall")),
      (Route<dynamic> route) => route.settings.name != 'conferenceCall',
    );
  }

  void _presentCall(CallSession session) {
    if (shell != null) {
      shell!.startCallSession(session);
      return;
    }

    if (session.conference) {
      Navigator.of(navKey.currentContext!).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => ConferenceCallScreen(session: session), settings: const RouteSettings(name: "conferenceCall")),
        (Route<dynamic> route) => route.settings.name != 'conferenceCall',
      );
    } else if (session.conversation != null && session.conversation!.conversationType == ConversationType.Group) {
      Navigator.of(navKey.currentContext!).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => MultiCallScreen(session: session), settings: const RouteSettings(name: "multiCall")),
        (Route<dynamic> route) => route.settings.name != 'multiCall',
      );
    } else {
      VoipCallScreen callView = VoipCallScreen(session: session);
      navKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => callView, settings: const RouteSettings(name: "singleCall")),
          (Route<dynamic> route) => route.settings.name != 'singleCall');
    }
  }

  @override
  void onReceiveCall(CallSession session) {
    debugPrint('onReceiveCall: ${session.callId}');
    CallKitService.instance.onReceiveCall(session);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (session.status != CallState.STATUS_IDLE) {
        _presentCall(session);
      }
    });
  }

  @override
  void onStartCall(CallSession session) {
    debugPrint('onStartCall: ${session.callId}');
    _presentCall(session);
  }

  @override
  void shouldStartRing(bool isIncoming) {
    debugPrint('shouldStartRing: $isIncoming');
  }

  @override
  void shouldStopRing() {
    debugPrint('shouldStopRing');
  }
}

