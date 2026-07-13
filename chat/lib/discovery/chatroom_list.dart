import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/chatroom_info.dart';
import 'package:imclient/model/conversation.dart';

import '../conversation/conversation_screen.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_typography.dart';

class ChatroomList extends StatelessWidget {
  final List modelList = ['chatroom1', 'chatroom2', 'chatroom3'];

  ChatroomList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktopShell
          ? const PcPageHeader(title: "消息设置")
          : AppBar(title: const Text("消息设置")),
      body: SafeArea(
        child: ListView.builder(
          itemCount: modelList.length,
          itemBuilder: (BuildContext context, int index) {
            return _buildRow(context, index);
          },
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    String chatroomId = modelList[index];
    return ChatroomItem(chatroomId);
  }
}

class ChatroomItem extends StatefulWidget {
  final String chatroomId;

  const ChatroomItem(this.chatroomId, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ChatroomItemState();

}

class ChatroomItemState extends State<ChatroomItem> {
  ChatroomInfo? chatroomInfo;

  @override
  void initState() {
    super.initState();
    Imclient.getChatroomInfo(widget.chatroomId, 0, (ci) {
      setState(() {
        chatroomInfo = ci;
      });
    }, (errorCode) {

    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Padding(padding: const EdgeInsets.all(8), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Container(child: Text((chatroomInfo == null || chatroomInfo!.title == null)?"聊天室":chatroomInfo!.title!, style: AppText.lg,),))],),
          // height 9 保留原 4+1+4 的行间留白。
          const Divider(height: 9, indent: 12, endIndent: 12),
        ],),),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ConversationScreen(Conversation(conversationType: ConversationType.Chatroom, target: widget.chatroomId))),
        );
      },
    );
  }

}