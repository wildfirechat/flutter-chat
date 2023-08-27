import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/user_info.dart';

import 'config.dart';

class SettingsTab extends StatelessWidget {

  List modelList = [
    ['assets/images/setting_message_notification.png', '消息通知', 'message_notification'],
    ['assets/images/setting_favorite.png', '收藏', 'favorite'],
    ['assets/images/setting_file.png', '文件', 'file'],
    ['assets/images/setting_safety.png', '账户安全', 'account_safety'],
    ['assets/images/setting_general.png', '设置', 'settings'],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
          itemCount: modelList.length+1,
          itemBuilder: (BuildContext context, int index) {
            if(index == 0) {
              return _buildMeRow(context);
            } else {
              return _buildRow(context, index-1);
            }
          },
        ),
      ),
    );
  }

  Widget _buildMeRow(BuildContext context) {
    return SettingProfile();
  }

  Widget _buildRow(BuildContext context, int index) {
    Image image = Image.asset(modelList[index][0], width: 20.0, height: 20.0);
    String title = modelList[index][1];
    return GestureDetector(child: Column(children: [
      Container(
        height: 18,
        width: View.of(context).physicalSize.width,
        color: const Color(0xffebebeb),
      ),
      Container(margin: const EdgeInsets.fromLTRB(10, 10, 5, 10), height: 36, child: Row(children: [image, Expanded(child: Container(margin: EdgeInsets.only(left: 15), child: Text(title),))],),),
      Container(
        margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
        height: 0.5,
        color: const Color(0xdbdbdbdb),
      ),
    ],),
      onTap: () {
        Fluttertoast.showToast(msg: "方法没有实现");
        print("on tap item $index");
      },);
  }
}

class SettingProfile extends StatefulWidget {
  const SettingProfile({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return SettingProfileState();
  }

}

class SettingProfileState extends State<SettingProfile> {
  UserInfo? userInfo;
  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;
  final EventBus _eventBus = Imclient.IMEventBus;


  @override
  void initState() {
    loadUserInfo();
    _userInfoUpdatedSubscription = _eventBus.on<UserInfoUpdatedEvent>().listen((event) {
      loadUserInfo();
    });
  }

  void loadUserInfo() {
    Imclient.currentUserId.then((userId) => {
      Imclient.getUserInfo(userId).then((ui) => {
        setState((){
          userInfo = ui;
        })
      })
    });
  }


  @override
  Widget build(BuildContext context) {
    if(userInfo == null) {
      return const Text("加载中。。。");
    } else {
      return GestureDetector(
        child: Container(
          height: 80,
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              Container(
                height: 60,
                width: 60,
                margin: const EdgeInsets.only(right: 16),
                child: userInfo!.portrait == null ? Image.asset(Config.defaultUserPortrait, width: 32.0, height: 32.0) : Image.network(userInfo!.portrait!, width: 32.0, height: 32.0),
              ),
              Container(
                margin: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userInfo!.displayName!, textAlign: TextAlign.left, style: const TextStyle(fontSize: 18),),
                    Container(margin: const EdgeInsets.only(top: 5),),
                    Container(constraints: BoxConstraints(maxWidth: View.of(context).physicalSize.width/View.of(context).devicePixelRatio - 100), child: Text('野火号:${userInfo!.name}', textAlign: TextAlign.left, style: const TextStyle(fontSize: 12, color: Color(0xFF3b3b3b), ), overflow: TextOverflow.ellipsis,),)
                  ],
                ),
              )
            ],
          ),
        ),
        onTap: () {

        },
      );
    }
  }

}
