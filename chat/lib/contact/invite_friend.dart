import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';

class InviteFriendPage extends StatefulWidget {
  const InviteFriendPage(this.userId, {super.key});
  final String userId;

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
    final actions = [
      TextButton(
        onPressed: () => _sendInvite(context),
        child: Text(
          "发送",
          style: TextStyle(
            color: fieldController.value.text.isEmpty
                ? Colors.grey
                : (isDesktopShell ? PcTheme.accent : Colors.black),
          ),
        ),
      ),
    ];

    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: '添加好友',
              onBack: () => Navigator.of(context).maybePop(),
              actions: actions,
            )
          : AppBar(
              actions: actions,
              title: const Text('添加好友'),
            ),
      backgroundColor: isDesktopShell ? PcTheme.chatBg : null,
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