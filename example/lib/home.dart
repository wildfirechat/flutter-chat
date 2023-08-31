// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:badges/badges.dart' as badge;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wfc_example/contact/search_user.dart';
import 'package:wfc_example/settings.dart';

import 'contact/contact_list_widget.dart';
import 'conversation_list_widget.dart';
import 'discovery.dart';

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

  int unreadCount = 0;

  Image getTabImage(path) {
    return Image.asset(path, width: 20.0, height: 20.0);
  }

  @override
  void initState() {
    super.initState();
    pages = <Widget>[ConversationListWidget((int count) {
      setState(() {
        unreadCount = count;
      });
    },), ContactListWidget(), DiscoveryTab(), SettingsTab()];
    tabImages ??= [
        [
          getTabImage('assets/images/tabbar_chat.png'),
          getTabImage('assets/images/tabbar_chat_cover.png')
        ],
        [
          getTabImage('assets/images/tabbar_contact.png'),
          getTabImage('assets/images/tabbar_contact_cover.png')
        ],
        [
          getTabImage('assets/images/tabbar_discover.png'),
          getTabImage('assets/images/tabbar_discover_cover.png')
        ],
        [
          getTabImage('assets/images/tabbar_me.png'),
          getTabImage('assets/images/tabbar_me_cover.png')
        ]
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

  void _onTapSearchButton(BuildContext context) {

  }

  void _startChat() {

  }

  void _addFriend() {
    showSearch(context: context, delegate: SearchUserDelegate());
  }

  void _scanQrCode() {

  }

  @override
  Widget build(BuildContext context) {
    _body = IndexedStack(
      children: pages,
      index: _tabIndex,
    );
    return Scaffold(//布局结构
        appBar: AppBar(//选中每一项的标题和图标设置
            title: Text(appBarTitles[_tabIndex], style: const TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
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
                      const PopupMenuItem(value: "chat",child: ListTile(leading: Icon(Icons.chat_bubble_rounded), title: Text("发起聊天"),),),
                      const PopupMenuItem(value: "add",child: ListTile(leading: Icon(Icons.contact_phone_rounded), title: Text("添加好友"),),),
                      const PopupMenuItem(value: "scan",child: ListTile(leading: Icon(Icons.qr_code_scanner_rounded), title: Text("扫描二维码"),),),
                    ];
                  },
                onSelected: (value) {
                    switch(value) {
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
        bottomNavigationBar: CupertinoTabBar(//
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                icon: badge.Badge(
                  badgeContent: Text('$unreadCount'),
                  showBadge: unreadCount > 0,
                  child: getTabIcon(0),
                ),
                label: getTabTitle(0)),
            BottomNavigationBarItem(
                icon: getTabIcon(1),
                label: getTabTitle(1)),
            BottomNavigationBarItem(
                icon: getTabIcon(2),
                label: getTabTitle(2)),
            BottomNavigationBarItem(
                icon: getTabIcon(3),
                label: getTabTitle(3)),
          ],
          currentIndex: _tabIndex,
          onTap: (index) {
            setState((){
              _tabIndex = index;
            });
          },
        ),
    );
  }
}
