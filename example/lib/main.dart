import 'dart:async';

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
import 'package:rtckit/group_video_call.dart';
// import 'package:momentclient/momentclient.dart';
import 'package:rtckit/rtckit.dart';
import 'package:rtckit/single_voice_call.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfc_example/splash.dart';

import 'config.dart';
import 'contact/contact_select_page.dart';
import 'default_portrait_provider.dart';
import 'home/home.dart';
import 'login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final navKey = GlobalKey<NavigatorState>();

  bool? isLogined;

  @override
  void initState() {
    super.initState();
    _initIMClient();
    SystemChannels.lifecycle.setMessageHandler((message) async {
      if(message == "AppLifecycleState.inactive") {
        debugPrint("goto background");
        updateAppBadge();
      }
    });
  }

  Future<void> _initIMClient() async {
    Rtckit.init(
        didReceiveCallCallback: (callSession) {
          //收到来电请求后，延迟100毫秒，判断是否来电已经结束，解决离线时先拨打再挂掉的问题。
          Future.delayed(const Duration(milliseconds: 100), () {
            //收到来电通知，原生代码会自动弹出来电界面。如果在后台，这里要弹出本地通知，本地通知带上震铃声。
            debugPrint('didReceiveCallCallback: ${callSession.callId}');
            Rtckit.currentCallSession().then((cs) {
              if(cs != null && cs.state != kWFAVEngineStateIdle) {
                if(cs.conversation!.conversationType == ConversationType.Single) {
                  SingleVideoCallView callView = SingleVideoCallView(
                      callSession: cs);
                  navKey.currentState!.push(
                      MaterialPageRoute(builder: (context) => callView));
                } else if(cs.conversation!.conversationType == ConversationType.Group) {
                  GroupVideoCallView callView = GroupVideoCallView(
                      callSession: cs);
                  navKey.currentState!.push(
                      MaterialPageRoute(builder: (context) => callView));
                }
              }
            });
          });
        },
        shouldStartRingCallback: (incoming) {
          //原生代码通知上层播放铃声。如果在后台就开始震动，如果在前台就播放铃声。这样做的原因是有些系统限制后台播放声音。
          debugPrint('shouldStartRingCallback: $incoming');
        },
        shouldStopRingCallback: () {
          //原生代码通知上层停止铃声和震动。
          debugPrint('shouldStopRingCallback');
        },
        didEndCallCallback: (reason, duration) {
          //原生代码通知上层通话结束。
          debugPrint('didEndCallCallback: $reason, $duration');
        });
    //Rtckit.enableCallkit();
    if (Config.ICE_SERVERS != null){
      for (int i = 0; i < Config.ICE_SERVERS.length; i ++){
        var iceServer = Config.ICE_SERVERS[i];
        Rtckit.addICEServer(iceServer[0], iceServer[1], iceServer[2]);
      }
    }

    Rtckit.defaultUserPortrait = Config.defaultUserPortrait;
    Rtckit.selectMembersDelegate = (BuildContext context, List<String> candidates, List<String>? disabledCheckedUsers, List<String>? disabledUncheckedUsers, int maxSelected, void Function(List<String> selectedMembers) callback) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ContactSelectPage((context, members) async {
          callback(members);
        },
          maxSelected: maxSelected,
          candidates: candidates,
          disabledCheckedUsers: disabledCheckedUsers,
          disabledUncheckedUsers: disabledUncheckedUsers
        )),
      );
    };

    Imclient.setDefaultPortraitProvider(WFPortraitProvider());

    Imclient.init((int status) {
      if (kDebugMode) {
        print(status);
      }
      if (status == kConnectionStatusSecretKeyMismatch ||
          status == kConnectionStatusTokenIncorrect ||
          status == kConnectionStatusRejected ||
          status == kConnectionStatusKickedOff ||
          status == kConnectionStatusLogout) {
        if(status != kConnectionStatusLogout) {
          Imclient.isLogined.then((value) {
            if(value) {
              Imclient.disconnect();
            }
          });
        }
        SharedPreferences.getInstance().then((value) {
          value.remove('userId');
          value.remove('token');
          value.commit();
        });

        isLogined = false;
        navKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen(), maintainState: true),
              (Route<dynamic> route) => false,
        );
      }
    }, (List<Message> messages, bool hasMore) {
      if (kDebugMode) {
        print(messages);
      }
    }, (messageUid) {
      if (kDebugMode) {
        print('recall message ${messageUid}');
      }
    }, (messageUid) {
      if (kDebugMode) {
        print('delete message ${messageUid}');
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
        print("on group ${groupId} member updated $members");
      }
    }, userInfoUpdatedCallback: (List<UserInfo> userInfos) {
      for (var element in userInfos) {
        debugPrint('on ${element.userId} user info updated');
      }
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
      Imclient.connect(
          Config.IM_Host, prefs.getString("userId")!, prefs.getString("token")!);
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
    //
    // MomentClient.init((comment) {
    //   debugPrint("receive comment");
    // }, (feed){
    //   debugPrint("receive feed");
    // });
  }

  void updateAppBadge() {
    //只有iOS平台支持，android平台不支持。如果有其他支持android平台badge，请提issue给我们添加。
    if(defaultTargetPlatform == TargetPlatform.iOS) {
      Imclient.isLogined.then((isLogined) {
        if (isLogined) {
          Imclient.getConversationInfos([
            ConversationType.Single,
            ConversationType.Group,
            ConversationType.Channel
          ], [0]).then((value) {
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
      navigatorKey: navKey,
      home: isLogined == null ? const SplashScreen() : (isLogined! ? const HomeTabBar() : LoginScreen()),
    );
  }
}
