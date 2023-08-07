import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/read_report.dart';
import 'package:imclient/model/user_info.dart';
import 'package:imclient/model/user_online_state.dart';
import 'package:rtckit/rtckit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'home.dart';
import 'login_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isLogined = false;

  @override
  void initState() {
    super.initState();
    _initIMClient();
  }

  Future<void> _initIMClient() async {
    Rtckit.init();
    if (Config.ICE_SERVERS != null){
      for (int i = 0; i < Config.ICE_SERVERS.length; i ++){
        var iceServer = Config.ICE_SERVERS[i];
        Rtckit.addICEServer(iceServer[0], iceServer[1], iceServer[2]);
      }
    }
    Imclient.init((int status) {
      print(status);
      if (status == kConnectionStatusSecretKeyMismatch ||
          status == kConnectionStatusTokenIncorrect ||
          status == kConnectionStatusRejected ||
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

        setState(() {
          isLogined = false;
        });
      }
    }, (List<Message> messages, bool hasMore) {
      print(messages);
    }, (messageUid) {
      print('recall message ${messageUid}');
    }, (messageUid) {
      print('delete message ${messageUid}');
    }, messageDeliveriedCallback: (Map<String, int> deliveryMap) {
      print('on message deliveried $deliveryMap');
    }, messageReadedCallback: (List<ReadReport> readReports) {
      print("on message readed $readReports");
    }, groupInfoUpdatedCallback: (List<GroupInfo> groupInfos) {
      print("on groupInfo updated $groupInfos");
    }, groupMemberUpdatedCallback: (String groupId, List<GroupMember> members) {
      print("on group ${groupId} member updated $members");
    }, userInfoUpdatedCallback: (List<UserInfo> userInfos) {
      print("on UserInfo updated $userInfos");
    }, channelInfoUpdatedCallback: (List<ChannelInfo> channelInfos) {
      print("on ChannelInfo updated $channelInfos");
    }, userSettingsUpdatedCallback: () {
      print("on user settings updated");
    }, friendListUpdatedCallback: (List<String> newFriendIds) {
      print("on friend list updated $newFriendIds");
    }, friendRequestListUpdatedCallback: (List<String> newFriendRequests) {
      print("on friend request updated $newFriendRequests");
    }, onlineEventCallback: (List<UserOnlineState> onlineInfos) {
      print(onlineInfos);
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getString("userId") != null && prefs.getString("token") != null) {
      Imclient.connect(
          Config.IM_Host, prefs.getString("userId")!, prefs.getString("token")!);
      setState(() {
        isLogined = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: isLogined ? HomeTabBar() : LoginScreen(),
    );
  }
}
