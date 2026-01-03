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
import 'package:chat/config.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/contact/search_user.dart';
import 'package:chat/search/search_portal_delegate.dart';
import 'package:chat/settings/me_tab.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/contact_list_view_model.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/viewmodel/group_conversation_info_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/workspace/work_space.dart';
import 'package:chat/scanner/qr_scanner_screen.dart';
import 'package:chat/group/group_info_screen.dart';
import 'package:chat/user_info_widget.dart';

import 'package:chat/wfc_scheme.dart';
import 'package:chat/pc/pc_login_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../contact/contact_list_widget.dart';
import '../conversation/conversation_screen.dart';
import '../discovery/discovery_tab.dart';
import 'conversation_list_widget.dart';

class HomeTabBar extends StatefulWidget {
  const HomeTabBar({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => HomeTabBarState();
}

class HomeTabBarState extends State<HomeTabBar> {
  late List<String> appBarTitles;
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
    appBarTitles = [];
    pages = <Widget>[const ConversationListWidget(), ContactListWidget(), const WorkSpace(), const DiscoveryTab(), const MeTab()];
    tabImages = [
      [getTabImage('assets/images/tabbar_chat.png'), getTabImage('assets/images/tabbar_chat_cover.png')],
      [getTabImage('assets/images/tabbar_contact.png'), getTabImage('assets/images/tabbar_contact_cover.png')],
      [getTabImage('assets/images/tabbar_work.png'), getTabImage('assets/images/tabbar_work_cover.png')],
      [getTabImage('assets/images/tabbar_discover.png'), getTabImage('assets/images/tabbar_discover_cover.png')],
      [getTabImage('assets/images/tabbar_me.png'), getTabImage('assets/images/tabbar_me_cover.png')]
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appBarTitles = [
      AppLocalizations.of(context)!.tabChat,
      AppLocalizations.of(context)!.tabContact,
      AppLocalizations.of(context)!.tabWork,
      AppLocalizations.of(context)!.tabDiscovery,
      AppLocalizations.of(context)!.tabMe
    ];

    if (Config.WORKSPACE_URL.isEmpty) {
      if (appBarTitles.length > 2) {
        appBarTitles.removeAt(2);
      }
      if (pages.length > 2) {
        pages.removeAt(2);
      }
      if (tabImages.length > 2) {
        tabImages.removeAt(2);
      }
    }
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
    showSearch(context: context, delegate: SearchPortalDelegate());
  }

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
          builder: (context) => PickUserScreen(title: AppLocalizations.of(context)!.startChat, (context, members) async {
                if (members.isEmpty) {
                  Fluttertoast.showToast(msg: "请选择一位或者多位好友发起聊天");
                } else if (members.length == 1) {
                  Conversation conversation = Conversation(conversationType: ConversationType.Single, target: members[0]);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => ConversationScreen(conversation)),
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
                      MaterialPageRoute(builder: (context) => ConversationScreen(conversation)),
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

  void _scanQrCode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QRScannerScreen()),
      );

      if (result != null && result is String) {
        if (mounted) {
          _handleQrCode(result);
        }
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.scanFail(e.toString()));
      }
    }
  }

  void _handleQrCode(String qrcode) {
    if (qrcode.isEmpty) return;

    String prefix;
    String value;

    int lastSlashIndex = qrcode.lastIndexOf('/');
    if (lastSlashIndex >= 0 && lastSlashIndex < qrcode.length - 1) {
      prefix = qrcode.substring(0, lastSlashIndex + 1);
      int questionMarkIndex = qrcode.indexOf('?');
      if (questionMarkIndex > lastSlashIndex) {
        value = qrcode.substring(lastSlashIndex + 1, questionMarkIndex);
      } else {
        value = qrcode.substring(lastSlashIndex + 1);
      }
    } else {
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.invalidQrCode(qrcode));
      return;
    }

    switch (prefix) {
      case WfcScheme.qrCodePrefixUser:
        Navigator.push(context, MaterialPageRoute(builder: (context) => UserInfoWidget(value)));
        break;
      case WfcScheme.qrCodePrefixGroup:
        // Parse from parameter if exists
        String? from;
        try {
          Uri uri = Uri.parse(qrcode);
          from = uri.queryParameters['from'];
        } catch (e) {
          // ignore
        }
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => GroupInfoScreen(groupId: value, from: from)));
        break;
      case WfcScheme.qrCodePrefixPcSession:
        Navigator.push(context, MaterialPageRoute(builder: (context) => PCLoginScreen(token: value)));
        break;
      case WfcScheme.qrCodePrefixChannel:
        // TODO: Implement Channel
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.channelNotSupport);
        break;
      case WfcScheme.qrCodePrefixConference:
        // TODO: Implement Conference
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.conferenceNotSupport);
        break;
      default:
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.scanResult(qrcode));
        break;
    }
  }

  Widget _buildBadge(int count, Widget child) {
    if (count == 0) {
      return child;
    }

    return badge.Badge(
      position: badge.BadgePosition.topEnd(top: 0, end: -12),
      badgeContent: count == -1 // Friend request indicator
          ? null
          : Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      badgeStyle: const badge.BadgeStyle(
        badgeColor: Colors.red
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    _body = IndexedStack(
      children: pages,
      index: _tabIndex,
    );
    return Scaffold(
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
                    PopupMenuItem(
                      value: "chat",
                      child: ListTile(
                        leading: const Icon(Icons.chat_bubble_rounded),
                        title: Text(AppLocalizations.of(context)!.startChat),
                      ),
                    ),
                    PopupMenuItem(
                      value: "add",
                      child: ListTile(
                        leading: const Icon(Icons.contact_phone_rounded),
                        title: Text(AppLocalizations.of(context)!.addFriend),
                      ),
                    ),
                    PopupMenuItem(
                      value: "scan",
                      child: ListTile(
                        leading: const Icon(Icons.qr_code_scanner_rounded),
                        title: Text(AppLocalizations.of(context)!.scanQrCode),
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
            items: List.generate(appBarTitles.length, (index) {
              if (index == 0) {
                return BottomNavigationBarItem(
                    icon: Selector<ConversationListViewModel, int>(
                      selector: (_, model) => model.unreadMessageCount,
                      builder: (context, unreadCount, child) =>
                          _buildBadge(unreadCount, getTabIcon(0)),
                    ),
                    label: getTabTitle(0));
              } else if (index == 1) {
                return BottomNavigationBarItem(
                    icon: Selector<ContactListViewModel, int>(
                      selector: (_, model) => model.unreadFriendRequestCount,
                      builder: (context, unreadFriendRequestCount, child) =>
                          _buildBadge(unreadFriendRequestCount > 0 ? -1 : 0, getTabIcon(1)),
                    ),
                    label: getTabTitle(1));
              } else {
                return BottomNavigationBarItem(icon: getTabIcon(index), label: getTabTitle(index));
              }
            }),
            currentIndex: _tabIndex,
            onTap: (index) {
              setState(() {
                _tabIndex = index;
              });
            },
          ),
        );
  }
}
