import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'dart:ui';

import 'package:wfc_example/config.dart';

class ContactListWidget extends StatefulWidget {
  @override
  _ContactListWidgetState createState() => _ContactListWidgetState();
}

class _ContactListWidgetState extends State<ContactListWidget> {
  List<String> friendList = [];
  List fixModelList = [
    ['assets/images/contact_new_friend.png', '新好友', 'new_friend'],
    ['assets/images/contact_fav_group.png', '收藏群组', 'fav_group'],
    ['assets/images/contact_subscribed_channel.png', '订阅频道', 'subscribed_channel'],
  ];


  @override
  void initState() {
    super.initState();
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

  Widget _contactRow(String userId, bool withSectionHeader, String? sectionTitle) {
    return ContactListItem(userId, withSectionHeader, sectionTitle);
  }

  Widget _fixRow(BuildContext context, int index) {
    String imagePaht = fixModelList[index][0];
    String title = fixModelList[index][1];
    return GestureDetector(
      onTap: () {

      },
      child: Column(
        children: <Widget>[
          Container(
            height: 48.0,
            margin: const EdgeInsets.fromLTRB(16.0, 0.0, 0.0, 0.0),
            child: Row(
              children: <Widget>[
                Image.asset(imagePaht, width: 32.0, height: 32.0),
                Expanded(
                    child: Container(
                        height: 40.0,
                        alignment: Alignment.centerLeft,
                        margin: const EdgeInsets.fromLTRB(15.0, 0.0, 0.0, 0.0),
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 15.0),
                        ))),
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
    return _ContactListItemState(userId);
  }
}

class _ContactListItemState extends State<ContactListItem> {
  String userId;
  UserInfo? userInfo;

  _ContactListItemState(this.userId) {

    Imclient.getUserInfo(userId).then((value) {
      setState(() {
        userInfo = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    String? portrait;
    String localPortrait;
    String convTitle;

      if(userInfo != null && userInfo?.portrait != null && userInfo!.portrait!.isNotEmpty) {
        portrait = userInfo!.portrait!;
        convTitle = userInfo!.displayName!;
      } else {
        convTitle = '私聊';
      }


    return GestureDetector(
      onTap: _toChatPage,
      child: Column(
        children: <Widget>[
          Container(
            height: widget.withSectionHeader?18:0,
            width: View.of(context).physicalSize.width/View.of(context).devicePixelRatio,
            color: const Color(0xffebebeb),
            child: widget.withSectionHeader && widget.sectionTitle != null ? Text(widget.sectionTitle!): null,
          ),
          Container(
            height: 48.0,
            margin: const EdgeInsets.fromLTRB(16.0, 0.0, 0.0, 0.0),
            child: Row(
              children: <Widget>[
                portrait == null ? Image.asset(Config.defaultUserPortrait, width: 32.0, height: 32.0) : Image.network(portrait, width: 32.0, height: 32.0),
                Expanded(
                    child: Container(
                        height: 40.0,
                        alignment: Alignment.centerLeft,
                        margin: const EdgeInsets.fromLTRB(15.0, 0.0, 0.0, 0.0),
                        child: Text(
                          convTitle,
                          style: const TextStyle(fontSize: 15.0),
                        ))),
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

  ///
  /// 跳转聊天界面
  ///
  ///
  _toChatPage() {
    // Navigator.push(
    //   context,
    //   new MaterialPageRoute(builder: (context) => new MessagesScreen()),
    // );
  }
}