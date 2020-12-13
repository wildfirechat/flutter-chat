import 'package:flutter/material.dart';
import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/model/user_info.dart';

class ContactListWidget extends StatefulWidget {
  @override
  _ContactListWidgetState createState() => _ContactListWidgetState();
}

class _ContactListWidgetState extends State<ContactListWidget> {
  List<String> friendList = new List();
  @override
  void initState() {
    super.initState();
    FlutterImclient.getMyFriendList(refresh: true).then((value){
      setState(() {
        friendList = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: ListView.builder(
          itemCount: friendList.length,
          itemBuilder: /*1*/ (context, i) {
            String userId = friendList[i];
            return _row(userId);
          }),),
    );
  }

  Widget _row(String userId) {
    return ContactListItem(userId);
  }
}

class ContactListItem extends StatefulWidget {
  String userId;

  ContactListItem(this.userId);

  @override
  State<StatefulWidget> createState() {
    return _ContactListItemState(userId);
  }
}

class _ContactListItemState extends State<ContactListItem> {
  String userId;
  UserInfo userInfo;

  var defaultAvatar = 'assets/images/user_avatar_default.png';

  _ContactListItemState(this.userId) {

    FlutterImclient.getUserInfo(userId).then((value) {
      setState(() {
        userInfo = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    String portrait;
    String localPortrait;
    String convTitle;

      if(userInfo != null && userInfo.portrait != null && userInfo.portrait.isNotEmpty) {
        portrait = userInfo.portrait;
        convTitle = userInfo.displayName;
      } else {
        convTitle = '私聊';
      }
      localPortrait = 'assets/images/user_avatar_default.png';


    return new GestureDetector(
      child: new Container(
        child: new Column(
          children: <Widget>[
            new Container(
              height: 48.0,
              margin: new EdgeInsets.fromLTRB(16.0, 0.0, 0.0, 0.0),
              child: new Row(
                children: <Widget>[
                  portrait == null ? new Image.asset(localPortrait, width: 32.0, height: 32.0) : Image.network(portrait, width: 32.0, height: 32.0),
                  new Expanded(
                      child: new Container(
                          height: 40.0,
                          alignment: Alignment.centerLeft,
                          margin: new EdgeInsets.fromLTRB(15.0, 0.0, 0.0, 0.0),
                          child: new Text(
                            '$convTitle',
                            style: TextStyle(fontSize: 15.0),
                          ))),
                ],
              ),
            ),
            new Container(
              margin: new EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
              height: 0.5,
              color: const Color(0xffebebeb),
            ),
          ],
        ),
      ),
      onTap: _toChatPage,
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