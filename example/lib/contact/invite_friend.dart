import 'package:flutter/material.dart';

class InviteFriendPage extends StatefulWidget {
  InviteFriendPage(this.userId, {Key? key}) : super(key: key);
  String userId;

  @override
  State<StatefulWidget> createState() => InviteFriendPageState();
}

class InviteFriendPageState extends State<InviteFriendPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(onPressed: (){}, child: Text("发送")),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Text("请填入申请理由，等待对方同意"),
          ],
        ),),
    );
  }

}