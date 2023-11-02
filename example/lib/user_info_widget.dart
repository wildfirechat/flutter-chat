import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:rtckit/rtckit.dart';
import 'package:rtckit/single_voice_call.dart';
import 'package:wfc_example/config.dart';
import 'package:wfc_example/contact/invite_friend.dart';

import 'messages/messages_screen.dart';

class UserInfoWidget extends StatefulWidget {
  UserInfoWidget(this.userId, {this.inGroupId, Key? key}) : super(key: key);
  String userId;
  String? inGroupId;

  @override
  State<StatefulWidget> createState() {
    return _UserInfoState();
  }
}

class _UserInfoState extends State<UserInfoWidget> {
  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;
  final List friendModelList = [
    //标题，key，是否带有section，是否居中，是否标红
    ['设置昵称或者别名', 'alias', false, false, false],
    ['更多信息', 'more', true, false, false],
    ['发送消息', 'message', true, true, false],
    ['视频聊天', 'voip', false, true, true],
  ];

  final List strangerModelList = [
    //标题，key，是否带有section，是否居中，是否标红
    ['更多信息', 'more', true, false, false],
    ['添加好友', 'friend', true, true, false],
  ];

  List? modelList;
  UserInfo? userInfo;
  bool isFriend = false;

  @override
  void initState() {
    super.initState();
    _userInfoUpdatedSubscription = _eventBus.on<UserInfoUpdatedEvent>().listen((event) {
      for(UserInfo userInfo in event.userInfos) {
        if(userInfo.userId == widget.userId) {
          loadUserInfo();
          break;
        }
      }
    });

    Imclient.isMyFriend(widget.userId).then((value) {
      isFriend = value;
      if(value) {
        modelList = friendModelList;
      } else {
        modelList = strangerModelList;
    }
    });

    loadUserInfo();
  }


  @override
  void dispose() {
    super.dispose();
    _userInfoUpdatedSubscription.cancel();
  }

  void loadUserInfo() {
    Imclient.getUserInfo(widget.userId, groupId: widget.inGroupId, refresh: true).then((value) => {
      setState((){
        userInfo = value;
      })
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: SafeArea(
        child: userInfo == null || modelList == null ? const Text("加载中。。。") : ListView.builder(
          itemCount: modelList!.length+1,
          itemBuilder: (BuildContext context, int index) {
            return index == 0 ? _buildHeader(context):_buildRow(context, index-1);
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if(userInfo == null) {
      return const Text("加载中。。。");
    } else {
      String? portrait;
      if(userInfo != null && userInfo!.portrait != null && userInfo!.portrait!.isNotEmpty) {
        portrait = userInfo!.portrait;
      }

      List<Widget> nameList = [];
      nameList.add(Text(userInfo!.displayName!, textAlign: TextAlign.left, style: const TextStyle(fontSize: 18),));
      bool hasAlias = isFriend && userInfo!.friendAlias != null && userInfo!.friendAlias!.isNotEmpty;
      nameList.add(Container(margin: EdgeInsets.only(top: hasAlias?3:6),));
      if(hasAlias) {
        nameList.add(Text('备注名:${userInfo!.friendAlias!}', textAlign: TextAlign.left, style: const TextStyle(fontSize: 12),));
        nameList.add(Container(margin: EdgeInsets.only(top: hasAlias?3:6),));
      }
      nameList.add(Container(constraints: BoxConstraints(maxWidth: View.of(context).physicalSize.width/View.of(context).devicePixelRatio - 100), child: Text('野火号:${userInfo!.name}', textAlign: TextAlign.left, style: const TextStyle(fontSize: 12, color: Color(0xFF3b3b3b), ), overflow: TextOverflow.ellipsis,)));

      return Container(
        height: 80,
        margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            GestureDetector(
              child: Container(
                height: 60,
                width: 60,
                margin: const EdgeInsets.only(right: 16),
                child: portrait == null ? Image.asset(Config.defaultUserPortrait, width: 32.0, height: 32.0) : Image.network(portrait, width: 32.0, height: 32.0),
              ),
              onTap: () {
                //show user portrait
              },
            ),
            Container(
              margin: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: nameList,
              ),
            )
          ],
        ),
      );
    }
  }

  Widget _buildRow(BuildContext context, int index) {
    String title = modelList![index][0];
    String key = modelList![index][1];
    bool hasSection = modelList![index][2];
    bool center = modelList![index][3];
    bool red = modelList![index][4];
    Color color = red ? Colors.red:Colors.black;

    return GestureDetector(child: Column(children: [
      Container(
        height: hasSection?18:0,
        width: View.of(context).physicalSize.width,
        color: const Color(0xffebebeb),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
        height: 36,
        child: center?Center(child: Text(title, style: TextStyle(color: color),)):Row(children: [Expanded(child: Text(title)),],),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
        height: 0.5,
        color: const Color(0xdbdbdbdb),
      ),
    ],),
      onTap: () {
        if(key == "message") {
          Conversation conversation = Conversation(conversationType: ConversationType.Single, target: widget.userId);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MessagesScreen(conversation)),
          );
        } else if(key == "voip") {
          SingleVideoCallView callView = SingleVideoCallView(userId:widget.userId, audioOnly:false);
          Navigator.push(context, MaterialPageRoute(builder: (context) => callView));
        } else if(key == "friend") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => InviteFriendPage(widget.userId)),
          );
        } else {
          Fluttertoast.showToast(msg: "方法没有实现");
          print("on tap item $index");
        }
      },);
  }
}