import 'dart:async';
import 'dart:convert';

import 'package:avenginekit/engine/call_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/read_report.dart';
import 'package:imclient/model/user_info.dart';
import 'package:imclient/model/user_online_state.dart';
import 'package:provider/provider.dart';
import 'package:avenginekit/engine/avengine_callback.dart';
import 'package:avenginekit/engine/call_session.dart';
import 'package:avenginekit/engine/call_end_reason.dart';
import 'package:avenginekit/engine/avenginekit.dart';
import 'package:chat/call/voip_call_screen.dart';
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
import 'package:chat/wfc_notification_manager.dart';

import 'app_theme.dart';
import 'config.dart';

import 'default_portrait_provider.dart';
import 'home/home.dart';
import 'internal/app_state.dart';
import 'login_screen.dart';
import 'pc/pc_home.dart';
import 'pc/pc_qr_login_screen.dart';
import 'pc/pc_tray_manager.dart';
import 'pc/pc_window_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:chat/utils/show_toast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isDesktopShell) {
    await PCWindowManager().ensureInitialized();
  }
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<UserViewModel>(create: (_) => UserViewModel()),
      ChangeNotifierProvider<GroupViewModel>(create: (_) => GroupViewModel()),
      ChangeNotifierProvider<ChannelViewModel>(create: (_) => ChannelViewModel()),
      ChangeNotifierProvider<ConversationViewModel>(create: (_) => ConversationViewModel()),
      ChangeNotifierProvider<ConversationListViewModel>(create: (_) => ConversationListViewModel()),
      ChangeNotifierProvider<ContactListViewModel>(create: (_) => ContactListViewModel()),
      ChangeNotifierProvider<LocaleViewModel>(create: (_) => LocaleViewModel()),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final navKey = GlobalKey<NavigatorState>();

  bool? isLogined;
  bool _isBackground = false;
  late MainAVEngineCallback _avEngineCallback;

  @override
  void initState() {
    super.initState();
    setToastNavigatorKey(navKey);
    setPCWindowNavKey(navKey);
    if (isDesktopShell) {
      PCWindowManager().setupWindow();
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
    _avEngineCallback = MainAVEngineCallback(navKey);
    avEngineKit.init(_avEngineCallback);
    WfcNotificationManager().init();
    WfcNotificationManager().onNotificationTapped = _handleNotificationTap;

    SystemChannels.lifecycle.setMessageHandler((message) async {
      final state = parseStateFromString(message!);
      WidgetsBinding.instance.handleAppLifecycleStateChanged(state);
      if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
        _isBackground = true;
        debugPrint("goto background");
        updateAppBadge();
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

    Imclient.init((int status) {
      if (kDebugMode) {
        print(status);
      }
      if (status == kConnectionStatusSecretKeyMismatch ||
          status == kConnectionStatusTokenIncorrect ||
          status == kConnectionStatusRejected ||
          status == kConnectionStatusKickedOff ||
          status == kConnectionStatusLogout) {
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
        bool topIsLogin = false;
        navKey.currentState?.popUntil((route) {
          topIsLogin = route.settings.name == 'login';
          return true;
        });
        if (!topIsLogin) {
          navKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => isDesktopShell ? const PCQRLoginScreen() : const LoginScreen(), settings: const RouteSettings(name: 'login'), maintainState: true),
            (Route<dynamic> route) => false,
          );
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

    Imclient.startLog();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getString("userId") != null && prefs.getString("token") != null) {
      Imclient.connect(Config.IM_Host, prefs.getString("userId")!, prefs.getString("token")!);
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
        // 通过 PCShellViewModel 切换当前会话（需要右栏 Navigator 支持）
        // 目前先只做窗口激活,会话跳转待 P2 右栏 Navigator 完善后接入。
        debugPrint('Notification tapped, conversation: \$conversation');
      } else if (type == 'friend_request') {
        await windowManager.show();
        await windowManager.focus();
        debugPrint('Notification tapped, friend request');
      }
    } catch (e) {
      debugPrint('handle notification tap failed: \$e');
    }
  }

  void updateAppBadge() {
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
      try {
        FlutterDynamicIcon.setApplicationIconBadgeNumber(count);
      } catch (e) {
        debugPrint('unsupport app icon badge number platform');
      }
    } else if (isDesktopShell) {
      // 桌面端:Dock(macOS)/任务栏(Windows) badge 目前通过托盘角标/标题模拟
      // tray_manager 没有 setBadge API,先更新托盘 tooltip 和未读闪烁。
      PCTrayManager().updateUnreadCount(count);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleViewModel>(
      builder: (context, localeViewModel, _) {
        return MaterialApp(
          locale: localeViewModel.locale,
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
          theme: ThemeData(
            primarySwatch: Colors.blue,
            checkboxTheme: AppTheme.checkboxTheme,
          ),
        );
      },
    );
  }

  Widget _buildHome() {
    if (isLogined == null) {
      return const SplashScreen();
    } else if (!isLogined!) {
      return isDesktopShell ? const PCQRLoginScreen() : const LoginScreen();
    }
    return isDesktopShell ? const PCHome() : const HomeTabBar();
  }
}
class MainAVEngineCallback implements AVEngineCallback {
  final GlobalKey<NavigatorState> navKey;

  MainAVEngineCallback(this.navKey);

  @override
  void didCallEnded(CallEndReason reason, int duration) {
    debugPrint('didCallEnded: $reason, $duration');
  }

  @override
  void onJoinConference(CallSession session) {
    // TODO: implement onJoinConference
  }

  @override
  void onReceiveCall(CallSession session) {
    debugPrint('onReceiveCall: ${session.callId}');
    Future.delayed(const Duration(milliseconds: 100), () {
      if (session.status != CallState.STATUS_IDLE) {
        if (isDesktopShell) {
          PCShellViewModel.global?.startCallSession(session);
          return;
        }
        if (session.conversation!.conversationType == ConversationType.Single) {
          VoipCallScreen callView = VoipCallScreen(session: session);
          navKey.currentState!.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => callView, settings: const RouteSettings(name: "singleCall")),
              (Route<dynamic> route) => route.settings.name != 'singleCall');
        }
      }
    });
  }

  @override
  void onStartCall(CallSession session) {
    debugPrint('onStartCall: ${session.callId}');
    if (isDesktopShell) {
      PCShellViewModel.global?.startCallSession(session);
      return;
    }
    if (session.conversation!.conversationType == ConversationType.Single) {
      VoipCallScreen callView = VoipCallScreen(session: session);
      navKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => callView, settings: const RouteSettings(name: "singleCall")),
          (Route<dynamic> route) => route.settings.name != 'singleCall');
    }
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

