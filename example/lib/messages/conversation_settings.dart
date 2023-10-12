import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';

class ConversationSettingPage extends StatefulWidget {
  ConversationSettingPage(this.conversation, {Key? key}) : super(key: key);
  Conversation conversation;
  @override
  State<StatefulWidget> createState() => ConversationSettingPageState();
}

class ConversationSettingPageState extends State<ConversationSettingPage> {
  late ConversationInfo conversationInfo;
  List modelList = [];
  GroupInfo? groupInfo;
  ChannelInfo? channelInfo;
  UserInfo? channelOwner;
  bool isFavGroup = false;
  bool isHiddenMemberName = false;
  GroupMember? groupMember;

  void _initSingleConversationModel() {
    setState(() {
      modelList = [
        //title, has section, key, center, right arrow
        ['成员列表', false, "member_list", false, false],
        ['查找聊天内容', false, 'search', false, true],
        ['会话文件', false, 'files', false, true],

        ['消息免打扰', true, 'mute', false, false],
        ['置顶聊天', false, 'top', false, false],

        ['清空聊天记录', true, 'clear', true, false],
      ];
    });
  }
  void _initGroupConversationModel() {
    Imclient.getGroupInfo(widget.conversation.target).then((gi) {
      setState(() {
        groupInfo = gi;
      });
    });

    Imclient.isHiddenGroupMemberName(widget.conversation.target).then((value) {
      setState(() {
        isHiddenMemberName = value;
      });
    });

    Imclient.isFavGroup(widget.conversation.target).then((value) {
      setState(() {
        isFavGroup = value;
      });
    });

    Imclient.getGroupMember(widget.conversation.target, Imclient.currentUserId).then((GroupMember? gm) {
      if(gm != null) {
        setState(() {
          groupMember = gm;
          modelList = [
            //title, has section, key, center, right arrow
            ['成员列表', false, 'member_list', false, false],
            ['群聊名称', false, 'group_name', false, true],
            ['群二维码', false, 'group_qrcode', false, true],
            ['群公告', false, 'group_announcement', false, true],
            ['群备注', false, 'group_remark', false, true],
          ];
          if(groupMember!.type == GroupMemberType.Manager || groupMember!.type == GroupMemberType.Owner) {
            modelList.add(['群管理', false, 'group_mange', false, true]);
          }
          modelList.addAll(
              [
                ['查找聊天内容', true, 'search', false, true],
                ['会话文件', false, 'files', false, true],

                ['消息免打扰', true, 'mute', false, false],
                ['置顶聊天', false, 'top', false, false],
                ['保存到通讯录', false, 'favorite', false, false],

                ['我在本群的昵称', true, 'nickname', false, true],
                ['显示群成员昵称', false, 'display_name', false, false],

                ['清空聊天记录', true, 'clear', true, false],
              ]
          );
          if(groupMember!.type == GroupMemberType.Owner) {
            modelList.addAll([
              ['转移群组', false, 'transfer', true, false],
              ['解散群组', false, 'dismiss', true, false],
            ]);
          } else {
            modelList.add(['退出群组', false, 'quit', true, false]);
          }
        });
      }
    });
  }

  void _initChannelConversationModel() {
    Imclient.getChannelInfo(widget.conversation.target).then((ci) {
      if(ci != null && ci!.owner != null) {
        Imclient.getUserInfo(ci!.owner!).then((ui) {
          setState(() {
            channelOwner = ui;
          });
        });
      }

      setState(() {
        channelInfo = ci;
        modelList = [
          //title, has section, key, center
          ['频道名称', false, 'channel_name', false, true],
          ['频道拥有者', false, 'channel_owner', false, true],
          ['频道描述', false, 'channel_desc', false, true],

          ['查找聊天内容', true, 'search', false, true],
          ['会话文件', false, 'files', false, true],

          ['消息免打扰', true, 'mute', false, false],
          ['置顶聊天', false, 'top', false, false],

          ['清空聊天记录', true, 'clear', true, false],
          ['取消关注', true, 'unsubscribe', true, false],
        ];
      });
    });
  }

  @override
  void initState() {
    _loadData();
  }

  void _loadData() {
    Imclient.getConversationInfo(widget.conversation).then((conv) {
      conversationInfo = conv;
      if(widget.conversation.conversationType == ConversationType.Single) {
        _initSingleConversationModel();
      } else if(widget.conversation.conversationType == ConversationType.Group) {
        _initGroupConversationModel();
      } else if(widget.conversation.conversationType == ConversationType.Channel) {
        _initChannelConversationModel();
      }
    });
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
    bool arrow = modelList[index][4];

    return GestureDetector(child: Column(children: [
      Container(
        height: hasSection?18:0,
        width: View.of(context).physicalSize.width,
        color: const Color(0xffebebeb),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
        height: 36,
        child: center?Center(child: Text(title, style: const TextStyle(color: Colors.red),)):Row(children: [Text(title), Expanded(child: Container()), _rowRight(key), arrow?const Icon(Icons.chevron_right):Container()],),
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

  Widget _rowRight(String key) {
    switch(key) {
      case 'group_qrcode':
        return const Icon(Icons.qr_code);
      case 'group_announcement':
        return Container();
      case 'group_remark':
        if(groupInfo != null && groupInfo!.remark != null) {
          return Text(groupInfo!.remark!);
        } else {
          return Container();
        }
      case 'group_name':
        if(groupInfo != null && groupInfo!.name != null) {
          return Text(groupInfo!.name!);
        } else {
          return Container();
        }
      case 'nickname':
        if(groupMember != null && groupMember!.alias != null) {
          return Text(groupMember!.alias!);
        } else {
          return Container();
        }
      case 'mute':
        return Switch(value: conversationInfo.isSilent, onChanged: (enable) {
          setState(() {
            conversationInfo.isSilent = enable;
          });
          Imclient.setConversationSilent(widget.conversation, enable, () {}, (errorCode) {
            Fluttertoast.showToast(msg: "设置失败");
            _loadData();
          });
        });
      case 'top':
        return Switch(value: conversationInfo.isTop>0, onChanged: (enable) {
          setState(() {
            conversationInfo.isTop = enable?1:0;
          });
          Imclient.setConversationTop(widget.conversation, enable?1:0, () {}, (errorCode) {
            Fluttertoast.showToast(msg: "设置失败");
            _loadData();
          });
        });
      case 'favorite':
        return Switch(value: isFavGroup, onChanged: (enable) {
          setState(() {
            isFavGroup = enable;
          });
          Imclient.setFavGroup(widget.conversation.target, enable, () {}, (errorCode) {
            Fluttertoast.showToast(msg: "设置失败");
            _loadData();
          });
        });
      case 'display_name':
        return Switch(value: isHiddenMemberName, onChanged: (enable) {
          setState(() {
            isHiddenMemberName = enable;
          });
          Imclient.setHiddenGroupMemberName(widget.conversation.target, enable, () { }, (errorCode) {
            Fluttertoast.showToast(msg: "设置失败");
            _loadData();
          });
        });
      case 'channel_name':
        if(channelInfo != null && channelInfo!.name != null) {
          return Text(channelInfo!.name!);
        } else {
          return Container();
        }
      case 'channel_owner':
        if(channelOwner != null && channelOwner!.displayName != null) {
          return Text(channelOwner!.displayName!);
        } else {
          return Container();
        }
      case 'channel_desc':
        if(channelInfo != null && channelInfo!.desc != null) {
          return Text(channelInfo!.desc!);
        } else {
          return Container();
        }
      default:
        return Container();
    }
  }
}