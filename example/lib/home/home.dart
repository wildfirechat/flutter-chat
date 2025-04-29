// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:badges/badges.dart' as badge;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/contact/contact_select_page.dart';
import 'package:wfc_example/contact/search_user.dart';
import 'package:wfc_example/settings/settings.dart';
import 'package:wfc_example/viewmodel/channel_view_model.dart';
import 'package:wfc_example/viewmodel/contact_list_view_model.dart';
import 'package:wfc_example/viewmodel/conversation_list_view_model.dart';
import 'package:wfc_example/viewmodel/group_view_model.dart';
import 'package:wfc_example/viewmodel/user_view_model.dart';

import '../contact/contact_list_widget.dart';
import 'conversation_list_widget.dart';
import '../discovery/discovery.dart';
import '../messages/messages_screen.dart';

class HomeTabBar extends StatefulWidget {
  const HomeTabBar({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => HomeTabBarState();
}

class HomeTabBarState extends State<HomeTabBar> {
  final appBarTitles = ['信息', '联系人', '发现', '我的'];
  final tabTextStyleSelected = const TextStyle(color: Color(0xff3B9AFF));
  final tabTextStyleNormal = const TextStyle(color: Color(0xff969696));

  Color themeColor = Colors.orange;
  int _tabIndex = 0;

  var tabImages;
  var _body;
  var pages;

  Image getTabImage(path) {
    return Image.asset(path, width: 20.0, height: 20.0);
  }

  @override
  void initState() {
    super.initState();
    pages = <Widget>[const ConversationListWidget(), ContactListWidget(), const DiscoveryTab(), SettingsTab()];
    tabImages = [
      [getTabImage('assets/images/tabbar_chat.png'), getTabImage('assets/images/tabbar_chat_cover.png')],
      [getTabImage('assets/images/tabbar_contact.png'), getTabImage('assets/images/tabbar_contact_cover.png')],
      [getTabImage('assets/images/tabbar_discover.png'), getTabImage('assets/images/tabbar_discover_cover.png')],
      [getTabImage('assets/images/tabbar_me.png'), getTabImage('assets/images/tabbar_me_cover.png')]
    ];
  }

  TextStyle getTabTextStyle(int curIndex) {
    if (curIndex == _tabIndex) {
      return tabTextStyleSelected;
    }
    return tabTextStyleNormal;
  }

  Image getTabIcon(int curIndex) {
    if (curIndex == _tabIndex) {
      return tabImages[curIndex][1];
    }
    return tabImages[curIndex][0];
  }

  String getTabTitle(int curIndex) {
    return appBarTitles[curIndex];
  }

  void _onTapSearchButton(BuildContext context) {}

  void _dismissProcessingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _showProcessingDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      barrierDismissible: false, // 阻止用户点击外部关闭对话框
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(title),
            ],
          ),
        );
      },
    );
  }

  void _startChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ContactSelectPage((context, members) async {
                if (members.isEmpty) {
                  Fluttertoast.showToast(msg: "请选择一位或者多位好友发起聊天");
                } else if (members.length == 1) {
                  Conversation conversation = Conversation(conversationType: ConversationType.Single, target: members[0]);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => MessagesScreen(conversation)),
                  );
                } else {
                  _showProcessingDialog(context, "群组创建中...");

                  List<UserInfo> userInfos = await Imclient.getUserInfos(members);
                  UserInfo? creator = await Imclient.getUserInfo(Imclient.currentUserId);
                  String groupName = creator!.displayName!;
                  for (var user in userInfos) {
                    if (user.displayName != null) {
                      if ('$groupName,${user.displayName}'.length > 24) {
                        groupName = '$groupName等';
                        break;
                      } else {
                        groupName = '$groupName,${user.displayName}';
                      }
                    }
                  }

                  Imclient.createGroup(null, groupName, null, GroupType.Restricted.index, members, (strValue) {
                    _dismissProcessingDialog(context);
                    Conversation conversation = Conversation(conversationType: ConversationType.Group, target: strValue);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => MessagesScreen(conversation)),
                    );
                  }, (errorCode) {
                    _dismissProcessingDialog(context);
                    Fluttertoast.showToast(msg: '创建失败：$errorCode');
                  });
                }
              })),
    );
  }

  void _addFriend() {
    showSearch(context: context, delegate: SearchUserDelegate());
  }

  void _scanQrCode() {}

  @override
  Widget build(BuildContext context) {
    _body = IndexedStack(
      children: pages,
      index: _tabIndex,
    );
    return MultiProvider(
        providers: [
          ChangeNotifierProvider<ConversationListViewModel>(create: (_) => ConversationListViewModel()),
          ChangeNotifierProvider<UserViewModel>(create: (_) => UserViewModel()),
          ChangeNotifierProvider<GroupViewModel>(create: (_) => GroupViewModel()),
          ChangeNotifierProvider<ChannelViewModel>(create: (_) => ChannelViewModel()),
          ChangeNotifierProvider<ContactListViewModel>(create: (_) => ContactListViewModel()),
        ],
        child: Scaffold(
          //布局结构
          appBar: AppBar(
            //选中每一项的标题和图标设置
            title: Text(appBarTitles[_tabIndex]),
            centerTitle: false,
            actions: [
              GestureDetector(
                onTap: () => _onTapSearchButton(context),
                child: const Icon(Icons.search_rounded),
              ),
              const Padding(padding: EdgeInsets.only(left: 8)),
              PopupMenuButton<String>(
                icon: const Icon(Icons.add_circle_outline_rounded),
                offset: const Offset(10, 60),
                itemBuilder: (context) {
                  return [
                    const PopupMenuItem(
                      value: "chat",
                      child: ListTile(
                        leading: Icon(Icons.chat_bubble_rounded),
                        title: Text("发起聊天"),
                      ),
                    ),
                    const PopupMenuItem(
                      value: "add",
                      child: ListTile(
                        leading: Icon(Icons.contact_phone_rounded),
                        title: Text("添加好友"),
                      ),
                    ),
                    const PopupMenuItem(
                      value: "scan",
                      child: ListTile(
                        leading: Icon(Icons.qr_code_scanner_rounded),
                        title: Text("扫描二维码"),
                      ),
                    ),
                  ];
                },
                onSelected: (value) {
                  switch (value) {
                    case "chat":
                      _startChat();
                      break;
                    case "add":
                      _addFriend();
                      break;
                    case "scan":
                      _scanQrCode();
                      break;
                  }
                },
              ),
              const Padding(padding: EdgeInsets.only(left: 16)),
            ],
          ),
          body: _body,
          bottomNavigationBar: CupertinoTabBar(
            //
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                  icon: Selector<ConversationListViewModel, int>(
                    selector: (_, model) => model.unreadMessageCount,
                    builder: (context, unreadCount, child) => badge.Badge(
                      badgeContent: Text('$unreadCount'),
                      showBadge: unreadCount > 0,
                      child: getTabIcon(0),
                    ),
                  ),
                  label: getTabTitle(0)),
              BottomNavigationBarItem(
                  icon: Selector<ContactListViewModel, int>(
                    selector: (_, model) => model.unreadFriendRequestCount,
                    builder: (context, unreadFriendRequestCount, child) => badge.Badge(
                      badgeContent: Text('$unreadFriendRequestCount'),
                      showBadge: unreadFriendRequestCount > 0,
                      child: getTabIcon(1),
                    ),
                  ),
                  label: getTabTitle(1)),
              BottomNavigationBarItem(icon: getTabIcon(2), label: getTabTitle(2)),
              BottomNavigationBarItem(icon: getTabIcon(3), label: getTabTitle(3)),
            ],
            currentIndex: _tabIndex,
            onTap: (index) {
              setState(() {
                _tabIndex = index;
              });
            },
          ),
        ));
  }
}
