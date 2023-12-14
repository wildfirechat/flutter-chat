import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';

class InviteFriendPage extends StatefulWidget {
  InviteFriendPage(this.userId, {Key? key}) : super(key: key);
  String userId;

  @override
  State<StatefulWidget> createState() => InviteFriendPageState();
}

class InviteFriendPageState extends State<InviteFriendPage> {
  final fieldController = TextEditingController();


  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(onPressed: () =>_sendInvite(context), child: Text("发送", style: TextStyle(color: fieldController.value.text.isEmpty?Colors.grey:Colors.white),)),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text("请填入申请理由，等待对方同意"),),
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: CupertinoTextField(
              placeholder: '请输入理由',
              controller: fieldController,
              clearButtonMode: OverlayVisibilityMode.editing,
              autocorrect: false,
              onChanged: (text) {
                setState(() {

                });
              },
            ),)
          ],
        ),),
    );
  }

  void _sendInvite(BuildContext context) {
    if(fieldController.value.text.isNotEmpty) {
      Imclient.sendFriendRequest(widget.userId, fieldController.value.text, () {
        Fluttertoast.showToast(msg: '请求已发出！');
        Navigator.pop(context);
      }, (errorCode) {
        Fluttertoast.showToast(msg: '网络错误：$errorCode');
      });
    }
  }

}