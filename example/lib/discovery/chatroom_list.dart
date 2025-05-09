import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/chatroom_info.dart';
import 'package:imclient/model/conversation.dart';

import '../messages/messages.dart';

class ChatroomList extends StatelessWidget {
  final List modelList = ['chatroom1', 'chatroom2', 'chatroom3'];

  ChatroomList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("消息设置"),),
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
          Row(children: [Expanded(child: Container(child: Text((chatroomInfo == null || chatroomInfo!.title == null)?"聊天室":chatroomInfo!.title!, style: const TextStyle(fontSize: 16),),))],),
          Container(
            margin: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 4.0),
            height: 1,
            color: const Color(0xffebebeb),
          ),
        ],),),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Messages(Conversation(conversationType: ConversationType.Chatroom, target: widget.chatroomId))),
        );
      },
    );
  }

}