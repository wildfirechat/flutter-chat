import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/model/channel_info.dart';
import 'package:flutter_imclient/model/group_info.dart';
import 'package:flutter_imclient/model/group_member.dart';
import 'package:flutter_imclient/model/read_report.dart';
import 'package:flutter_imclient/model/user_info.dart';
import 'package:flutter_imclient_example/config.dart';
import 'package:flutter_imclient_example/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    FlutterImclient.init((int status) {
      print(status);
      if (status == kConnectionStatusSecretKeyMismatch ||
          status == kConnectionStatusTokenIncorrect ||
          status == kConnectionStatusRejected ||
          status == kConnectionStatusLogout) {
        if(status != kConnectionStatusLogout) {
          FlutterImclient.isLogined.then((value) {
            if(value) {
              FlutterImclient.disconnect();
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
      print("on groupInfo updated $userInfos");
    }, channelInfoUpdatedCallback: (List<ChannelInfo> channelInfos) {
      print("on groupInfo updated $channelInfos");
    }, userSettingsUpdatedCallback: () {
      print("on groupInfo updated");
    }, friendListUpdatedCallback: (List<String> newFriendIds) {
      print("on friend list updated $newFriendIds");
    }, friendRequestListUpdatedCallback: (List<String> newFriendRequests) {
      print("on friend request updated $newFriendRequests");
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getString("userId") != null && prefs.getString("token") != null) {
      FlutterImclient.connect(
          Config.IM_Host, prefs.getString("userId"), prefs.getString("token"));
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
