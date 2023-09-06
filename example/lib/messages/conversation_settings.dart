import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';

class ConversationSettingPage extends StatefulWidget {
  ConversationSettingPage(this.conversation, {Key? key}) : super(key: key);
  Conversation conversation;
  @override
  State<StatefulWidget> createState() => ConversationSettingPageState();
}

class ConversationSettingPageState extends State<ConversationSettingPage> {
  List modelList = [];
  
  @override
  void initState() {
    if(widget.conversation.conversationType == ConversationType.Single) {
      modelList = [
        //title, has section, key
        ['成员列表', false, "member_list", false],
        ['查找聊天内容', false, 'search', false],
        ['会话文件', false, 'files', false],

        ['消息免打扰', true, 'mute', false],
        ['置顶聊天', false, 'top', false],

        ['清空聊天记录', true, 'clear', true],
      ];
    } else if(widget.conversation.conversationType == ConversationType.Group) {
      Imclient.getGroupMember(widget.conversation.target, Imclient.currentUserId).then((GroupMember? groupMember) {
        if(groupMember != null) {
         setState(() {
           modelList = [
             //title, has section, key
             ['成员列表', false, 'member_list', false],
             ['群聊名称', false, 'group_name', false],
             ['群二维码', false, 'group_qrcode', false],
             ['群公告', false, 'group_announcement', false],
             ['群备注', false, 'group_remark', false],
           ];
           if(groupMember.type == GroupMemberType.Manager || groupMember.type == GroupMemberType.Owner) {
             modelList.add(['群管理', false, 'group_mange', false]);
           }
           modelList.addAll(
               [
                 ['查找聊天内容', true, 'search', false],
                 ['会话文件', false, 'files', false],

                 ['消息免打扰', true, 'mute', false],
                 ['置顶聊天', false, 'top', false],
                 ['保存到通讯录', false, 'favorite', false],

                 ['我在本群的昵称', true, 'nickname', false],
                 ['显示群成员昵称', false, 'display_name', false],

                 ['清空聊天记录', true, 'clear', true],
               ]
           );
           if(groupMember.type == GroupMemberType.Owner) {
             modelList.addAll([
               ['转移群组', false, 'transfer', true],
               ['解散群组', false, 'dismiss', true],
             ]);
           } else {
             modelList.add(['退出群组', false, 'quit', true]);
           }
         });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: modelList.isEmpty?const Center(child: CircularProgressIndicator(),):_getList(),
      ),
    );
  }
  
  Widget _getList() {
    return ListView.builder(
        itemCount: modelList.length, 
        itemBuilder: _buildRow 
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    //['成员列表', false, 'member_list', false],
    String title = modelList[index][0];
    bool hasSection = modelList[index][1];
    String key = modelList[index][2];
    bool center = modelList[index][3];

    return GestureDetector(child: Column(children: [
      Container(
        height: hasSection?18:0,
        width: View.of(context).physicalSize.width,
        color: const Color(0xffebebeb),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
        height: 36,
        child: center?Center(child: Text(title, style: const TextStyle(color: Colors.red),)):Row(children: [Expanded(child: Text(title)),],),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
        height: 0.5,
        color: const Color(0xdbdbdbdb),
      ),
    ],),
      onTap: () {
        if(key == "clear") {
            Imclient.clearMessages(widget.conversation).then((value) {
              Fluttertoast.showToast(msg: "清理成功");
            });
        } else {
          Fluttertoast.showToast(msg: "方法没有实现");
        }
      },);
  }
}