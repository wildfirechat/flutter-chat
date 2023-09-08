import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'dart:ui';

import 'package:wfc_example/config.dart';
import 'package:wfc_example/contact/friend_request_page.dart';
import 'package:wfc_example/user_info_widget.dart';

class ContactListWidget extends StatefulWidget {
  const ContactListWidget({Key? key}) : super(key: key);

  @override
  State createState() => _ContactListWidgetState();
}

class _ContactListWidgetState extends State<ContactListWidget> {
  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<UserSettingUpdatedEvent> _userSettingUpdatedSubscription;

  List<String> friendList = [];
  List fixModelList = [
    ['assets/images/contact_new_friend.png', '新好友', 'new_friend'],
    ['assets/images/contact_fav_group.png', '收藏群组', 'fav_group'],
    ['assets/images/contact_subscribed_channel.png', '订阅频道', 'subscribed_channel'],
  ];


  @override
  void initState() {
    super.initState();
    _loadFriendList(true);

    _userSettingUpdatedSubscription = _eventBus.on<UserSettingUpdatedEvent>().listen((event) {
      _loadFriendList(false);
    });
  }

  void _loadFriendList(bool refresh) {
    Imclient.getMyFriendList(refresh: true).then((value){
      setState(() {
        if(value != null) {
          friendList = value;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: ListView.builder(
          itemCount: fixModelList.length + friendList.length,
          itemBuilder: /*1*/ (context, i) {
            if(i < fixModelList.length) {
              return _fixRow(context, i);
            } else {
              String userId = friendList[i - fixModelList.length];
              return _contactRow(userId, i - fixModelList.length == 0, '');
            }
          }),),
    );
  }


  @override
  void dispose() {
    super.dispose();
    _userSettingUpdatedSubscription.cancel();
  }

  Widget _contactRow(String userId, bool withSectionHeader, String? sectionTitle) {
    return ContactListItem(userId, withSectionHeader, sectionTitle);
  }

  Widget _fixRow(BuildContext context, int index) {
    String imagePaht = fixModelList[index][0];
    String title = fixModelList[index][1];
    String key = fixModelList[index][2];
    return GestureDetector(
      onTap: () {
        if(key == "new_friend") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FriendRequestPage()),
          );
        } else {
          Fluttertoast.showToast(msg: "方法没有实现");
          print("on tap item $index");
        }
      },

      child: Column(
        children: <Widget>[
          Container(
            height: 52.0,
            margin: const EdgeInsets.fromLTRB(16.0, 0.0, 0.0, 0.0),
            child: Row(
              children: <Widget>[
                Image.asset(imagePaht, width: 40.0, height: 40.0),
                Container(margin: const EdgeInsets.only(left: 16),),
                Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 15.0),
                    )
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
            height: 0.5,
            color: const Color(0xffebebeb),
          ),
        ],
      ),
    );;
  }
}

class ContactListItem extends StatefulWidget {
  String userId;
  bool withSectionHeader;
  String? sectionTitle;

  ContactListItem(this.userId, this.withSectionHeader, this.sectionTitle, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _ContactListItemState();
  }
}

class _ContactListItemState extends State<ContactListItem> {
  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;

  UserInfo? userInfo;

  _ContactListItemState();


  @override
  void initState() {
    _loadUserInfo();
    _userInfoUpdatedSubscription = _eventBus.on<UserInfoUpdatedEvent>().listen((event) {
      _loadUserInfo();
    });
  }

  void _loadUserInfo() {
    Imclient.getUserInfo(widget.userId).then((value) {
      setState(() {
        userInfo = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    String? portrait;
    String convTitle;

      if(userInfo != null) {
        if(userInfo!.portrait != null && userInfo!.portrait!.isNotEmpty) {
          portrait = userInfo!.portrait!;
        }
        convTitle = userInfo!.displayName!;
      } else {
        convTitle = '用户';
      }


    return GestureDetector(
      onTap: _toUserInfoPage,
      child: Column(
        children: <Widget>[
          Container(
            height: widget.withSectionHeader?18:0,
            width: View.of(context).physicalSize.width/View.of(context).devicePixelRatio,
            color: const Color(0xffebebeb),
            child: widget.withSectionHeader && widget.sectionTitle != null ? Text(widget.sectionTitle!): null,
          ),
          Container(
            height: 52.0,
            margin: const EdgeInsets.fromLTRB(16.0, 0.0, 0.0, 0.0),
            child: Row(
              children: <Widget>[
                portrait == null ? Image.asset(Config.defaultUserPortrait, width: 40.0, height: 40.0) : Image.network(portrait, width: 40.0, height: 40.0),
                Container(margin: const EdgeInsets.only(left: 16),),
                Expanded(
                    child: Text(
                      convTitle,
                      style: const TextStyle(fontSize: 15.0),
                    )
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
            height: 0.5,
            color: const Color(0xffebebeb),
          ),
        ],
      ),
    );
  }


  @override
  void dispose() {
    super.dispose();
    _userInfoUpdatedSubscription.cancel();
  }

  ///
  /// 跳转聊天界面
  ///
  ///
  _toUserInfoPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserInfoWidget(widget.userId)),
    );
  }
}