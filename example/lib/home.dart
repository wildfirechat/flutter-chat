// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:badges/badges.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_imclient_example/contact_list_widget.dart';
import 'package:flutter_imclient_example/conversation_list_widget.dart';
import 'package:flutter_imclient_example/settings.dart';

class HomeTabBar extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => HomeTabBarState();
}

class HomeTabBarState extends State<HomeTabBar> {
  final appBarTitles = ['信息', '联系人', '发现', '我的'];
  final tabTextStyleSelected = TextStyle(color: const Color(0xff3B9AFF));
  final tabTextStyleNormal = TextStyle(color: const Color(0xff969696));

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
    pages = <Widget>[ConversationListWidget(unreadCountCallback: (int count) {
      setState(() {
        unreadCount = count;
      });
    },), ContactListWidget(), SettingsTab(), SettingsTab()];
    if (tabImages == null) {
      tabImages = [
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
  }

  TextStyle getTabTextStyle(int curIndex) {//设置tabbar 选中和未选中的状态文本
    if (curIndex == _tabIndex) {
      return tabTextStyleSelected;
    }
    return tabTextStyleNormal;
  }

  Image getTabIcon(int curIndex) {//设置tabbar选中和未选中的状态图标
    if (curIndex == _tabIndex) {
      return tabImages[curIndex][1];
    }
    return tabImages[curIndex][0];
  }

  String getTabTitle(int curIndex) {
    return appBarTitles[curIndex];
  }

  @override
  Widget build(BuildContext context) {
    _body = IndexedStack(
      children: pages,
      index: _tabIndex,
    );
    return Scaffold(//布局结构
        appBar: AppBar(//选中每一项的标题和图标设置
            title: Text(appBarTitles[_tabIndex],
                style: TextStyle(color: Colors.white)),
            iconTheme: IconThemeData(color: Colors.white)
        ),
        body: _body,
        bottomNavigationBar: CupertinoTabBar(//
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                icon: Badge(
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
