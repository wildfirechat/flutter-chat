import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/friend_request.dart';
import 'package:imclient/model/user_info.dart';

import '../config.dart';

class FriendRequestPage extends StatefulWidget {
  const FriendRequestPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => FriendRequestPageState();

}

class FriendRequestPageState extends State<FriendRequestPage> {
  List<FriendRequest> requests = [];
  Map<String, UserInfo> cachedUserInfos = {};

  @override
  void initState() {
    Imclient.clearUnreadFriendRequestStatus();
    _loadFriendRequestAndUserInfos();
  }

  void _loadFriendRequestAndUserInfos() {
    Imclient.getIncommingFriendRequest().then((value) {
      List<String> userIds = [];
      for(var f in value) {
        userIds.add(f.target);
      }

      Imclient.getUserInfos(userIds).then((userInfos) {
        setState(() {
          for(var ui in userInfos) {
            cachedUserInfos[ui.userId] = ui;
          }
          requests = value;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          GestureDetector(
            onTap: () => _clearAll(context),
            child: const Row(
              children: [
                Icon(Icons.delete_outline_rounded),
                Padding(padding: EdgeInsets.only(left: 16)),
              ],
            ),
          )
        ],
        title: const Text("好友请求"),),
      body: SafeArea(
        child: ListView.builder(
          itemCount: requests.length,
            itemBuilder: _buildRow),
      ),
    );
  }

  void _loadUserInfo(String userId) {

  }

  Widget _buildRow(BuildContext context, int index) {
    FriendRequest request = requests[index];
    UserInfo? userInfo = cachedUserInfos[request.target];
    if(userInfo == null) {
      _loadUserInfo(request.target);
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          (userInfo == null || userInfo!.portrait == null || userInfo!.portrait!.isEmpty) ? Image.asset(Config.defaultUserPortrait, width: 40.0, height: 40.0) : Image.network(userInfo!.portrait!, width: 40, height: 40,),
          const Padding(padding: EdgeInsets.all(8)),
          Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userInfo != null?userInfo!.getReadableName():"<${request.target}>"),
                  Text(request.reason??""),
                ],
              ),
          ),
          SizedBox(
            width: 80,
            child: Center(
              child: request.status == FriendRequestStatus.WaitingAccept?OutlinedButton(onPressed: ()=>_acceptRequest(request.target), child: const Text("通过")):(request.status == FriendRequestStatus.Accepted?const Text("已通过"):const Text("已拒接")),
            ),
          ),
        ],
      ),
    );
  }

  void _acceptRequest(String userId) {
    Imclient.handleFriendRequest(userId, true, "", () {
      Fluttertoast.showToast(msg: "已通过");
      _loadFriendRequestAndUserInfos();
    }, (errorCode) {
      if(errorCode == 19) {
        Fluttertoast.showToast(msg: "已过期");
      } else {
        Fluttertoast.showToast(msg: '网络错误：$errorCode');
      }
    });
  }

  void _clearAll(BuildContext context) {
    Imclient.clearFriendRequest(1);
    Navigator.pop(context);
  }
}