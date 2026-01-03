import 'dart:async';

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
import 'package:avenginekit/internal/avenginekit_impl.dart';
import 'package:chat/call/voip_call_screen.dart';

// import 'package:momentclient/momentclient.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat/splash.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/contact_list_view_model.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/wfc_notification_manager.dart';

import 'config.dart';
import 'contact/pick_user_screen.dart';

import 'default_portrait_provider.dart';
import 'home/home.dart';
import 'internal/app_state.dart';
import 'login_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<UserViewModel>(create: (_) => UserViewModel()),
      ChangeNotifierProvider<GroupViewModel>(create: (_) => GroupViewModel()),
      ChangeNotifierProvider<ChannelViewModel>(create: (_) => ChannelViewModel()),
      ChangeNotifierProvider<ConversationViewModel>(create: (_) => ConversationViewModel()),
      ChangeNotifierProvider<ConversationListViewModel>(create: (_) => ConversationListViewModel()),
      ChangeNotifierProvider<ContactListViewModel>(create: (_) => ContactListViewModel()),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

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
    _initIMClient();
    _initRepo();
    _avEngineCallback = MainAVEngineCallback(navKey);
    avEngineKit.init(_avEngineCallback);
    WfcNotificationManager().init();

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
    });

    Imclient.IMEventBus.on<FriendRequestUpdateEvent>().listen((event) {
      if (_isBackground) {
        WfcNotificationManager().handleFriendRequest(event.newUserRequests);
      }
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
        navKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen(), maintainState: true),
          (Route<dynamic> route) => false,
        );
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
    }, friendListUpdatedCallback: (List<String> newFriendIds) {
      if (kDebugMode) {
        print("on friend list updated $newFriendIds");
      }
    }, friendRequestListUpdatedCallback: (List<String> newFriendRequests) {
      if (kDebugMode) {
        print("on friend request updated $newFriendRequests");
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

  void updateAppBadge() {
    //只有iOS平台支持，android平台不支持。如果有其他支持android平台badge，请提issue给我们添加。
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      Imclient.isLogined.then((isLogined) {
        if (isLogined) {
          Imclient.getConversationInfos([ConversationType.Single, ConversationType.Group, ConversationType.Channel], [0]).then((value) {
            int unreadCount = 0;
            for (var element in value) {
              if (!element.isSilent) {
                unreadCount += element.unreadCount.unread;
              }
            }
            Imclient.getUnreadFriendRequestStatus().then((unreadFriendRequest) {
              unreadCount += unreadFriendRequest;
              try {
                FlutterDynamicIcon.setApplicationIconBadgeNumber(unreadCount);
              } catch (e) {
                debugPrint('unsupport app icon badge number platform');
              }
            });
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      ),
    );
  }

  Widget _buildHome() {
    if (isLogined == null) {
      return const SplashScreen();
    } else {
      return isLogined! ? const HomeTabBar() : const LoginScreen();
    }
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

