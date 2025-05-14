import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/messages/messages.dart';
import 'package:wfc_example/viewmodel/conversation_view_model.dart';
import 'package:wfc_example/viewmodel/group_view_model.dart';

import '../contact/pick_user_screen.dart';
import '../user_info_widget.dart';
import 'conversation_setting_all_members_view.dart';
import 'conversation_setting_members_view.dart';

class GroupConversationInfoScreen extends StatefulWidget {
  GroupConversationInfoScreen(this.conversation, {Key? key}) : super(key: key);
  Conversation conversation;

  @override
  State<StatefulWidget> createState() => GroupConversationInfoScreenState();
}

class GroupConversationInfoScreenState extends State<GroupConversationInfoScreen> {
  List optionList = [];
  GroupMember? groupMember;

  late GroupViewModel _groupViewModel;

  void _buildGroupConversationOptions() {
    groupMember = _groupViewModel.groupMember;
    if (groupMember != null) {
      optionList = [
        //title, has section, key, center, right arrow
        ['成员列表', false, 'member_list', false, false],
        ['群聊名称', true, 'group_name', false, true],
        ['群二维码', false, 'group_qrcode', false, true],
        ['群公告', false, 'group_announcement', false, true],
        ['群备注', false, 'group_remark', false, true],
      ];
      if (groupMember!.type == GroupMemberType.Manager || groupMember!.type == GroupMemberType.Owner) {
        optionList.add(['群管理', false, 'group_mange', false, true]);
      }
      optionList.addAll([
        ['查找聊天内容', true, 'search', false, true],
        ['会话文件', false, 'files', false, true],
        ['消息免打扰', true, 'mute', false, false],
        ['置顶聊天', false, 'top', false, false],
        ['保存到通讯录', false, 'favorite', false, false],
        ['我在本群的昵称', true, 'nickname', false, true],
        ['显示群成员昵称', false, 'display_name', false, false],
        ['清空聊天记录', true, 'clear', true, false],
      ]);
      if (groupMember!.type == GroupMemberType.Owner) {
        optionList.addAll([
          ['转移群组', false, 'transfer', true, false],
          ['解散群组', false, 'dismiss', true, false],
        ]);
      } else {
        optionList.add(['退出群组', false, 'quit', true, false]);
      }
    }
  }

  ConversationSettingMembersWidget? conversationSettingMembersWidget;

  @override
  void initState() {
    super.initState();

    // if(widget.conversation.conversationType == ConversationType.Single) {
    //   _userInfoUpdatedSubscription = _eventBus.on<UserInfoUpdatedEvent>().listen((event) {
    //
    //   });
    // } else if(widget.conversation.conversationType == ConversationType.Group) {
    //   _groupInfoUpdatedSubscription = _eventBus.on<GroupInfoUpdatedEvent>().listen((event) {
    //
    //   });
    //   _groupMembersUpdatedSubscription = _eventBus.on<GroupMembersUpdatedEvent>().listen((event) {
    //     setState(() {
    //       debugPrint("update here");
    //     });
    //   });
    // }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GroupViewModel>(
        create: (_) {
          _groupViewModel = GroupViewModel();
          _groupViewModel.setup(widget.conversation.target);
          return _groupViewModel;
        },
        child: Consumer<GroupViewModel>(
            builder: (context, viewModel, child) => Scaffold(
                  appBar: AppBar(),
                  body: SafeArea(
                    child: _groupViewModel.groupMember == null
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : _getList(),
                  ),
                )));
  }

  Widget _getList() {
    _buildGroupConversationOptions();
    return ListView.builder(itemCount: optionList.length, itemBuilder: _buildRow);
  }

  Widget _buildRow(BuildContext context, int index) {
    //['成员列表', false, 'member_list', false],
    String title = optionList[index][0];
    bool hasSection = optionList[index][1];
    String key = optionList[index][2];
    bool center = optionList[index][3];
    bool arrow = optionList[index][4];

    conversationSettingMembersWidget ??= ConversationSettingMembersWidget(
      widget.conversation,
      onItemClicked: (userId) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => UserInfoWidget(userId)),
        );
      },
      onPlusItemClicked: _onPlusItemClicked,
      onMinusItemClicked: _onMinusItemClicked,
      onShowMoreClicked: (groupMembers, hasPlus, hasMinus) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GroupAllMembersWidget(widget.conversation.target, groupMembers, hasPlus, hasMinus)),
        );
      },
    );

    return GestureDetector(
      child: Column(
        children: [
          Container(
            height: hasSection ? 18 : 0,
            width: View.of(context).physicalSize.width,
            color: const Color(0xffebebeb),
          ),
          key == 'member_list'
              ? conversationSettingMembersWidget!
              : Container(
                  margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
                  height: 36,
                  child: (center
                      ? Center(
                          child: Text(
                          title,
                          style: const TextStyle(color: Colors.red),
                        ))
                      : Row(
                          children: [Text(title), Expanded(child: Container()), _rowRight(key), arrow ? const Icon(Icons.chevron_right) : Container()],
                        )),
                ),
          Container(
            margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
            height: 0.5,
            color: const Color(0xdbdbdbdb),
          ),
        ],
      ),
      onTap: () {
        if (key == "clear") {
          Imclient.clearMessages(widget.conversation).then((value) {
            Fluttertoast.showToast(msg: "清理成功");
          });
        } else {
          Fluttertoast.showToast(msg: "方法没有实现");
        }
      },
    );
  }

  void _onMinusItemClicked() {
    Imclient.getGroupMembers(widget.conversation.target).then((value) {
      if (value.isNotEmpty) {
        List<String> memberIds = [];
        for (var value1 in value) {
          memberIds.add(value1.memberId);
        }
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PickUserScreen(
                    (context, members) async {
                      if (members.isEmpty) {
                        Navigator.pop(context);
                      } else {
                        Imclient.kickoffGroupMembers(widget.conversation.target, members, () {
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 100), () {
                            setState(() {});
                          });
                        }, (errorCode) {});
                      }
                    },
                    disabledUncheckedUsers: [Imclient.currentUserId],
                    candidates: memberIds,
                  )),
        );
      }
    });
  }

  void _onPlusItemClicked() {
    if (widget.conversation.conversationType == ConversationType.Group) {
      Imclient.getGroupMembers(widget.conversation.target).then((value) {
        if (value.isNotEmpty) {
          List<String> memberIds = [];
          for (var value1 in value) {
            memberIds.add(value1.memberId);
          }
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => PickUserScreen((context, members) async {
                      if (members.isEmpty) {
                        Navigator.pop(context);
                        return;
                      }
                      Imclient.addGroupMembers(widget.conversation.target, members, () {
                        Navigator.pop(context);
                        Future.delayed(const Duration(milliseconds: 100), () {
                          setState(() {});
                        });
                      }, (errorCode) {
                        Fluttertoast.showToast(msg: "网络错误");
                      });
                    }, disabledUncheckedUsers: memberIds)),
          );
        }
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => PickUserScreen(
                  (context, members) async {
                    Navigator.pop(context);
                    if (members.isNotEmpty) {
                      Imclient.createGroup(null, null, null, 2, members, (strValue) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => Messages(Conversation(conversationType: ConversationType.Group, target: strValue))),
                        );
                      }, (errorCode) {
                        Fluttertoast.showToast(msg: "网络错误");
                      });
                    }
                  },
                  disabledCheckedUsers: [widget.conversation.target],
                )),
      );
    }
  }

  Widget _rowRight(String key) {
    var groupInfo = _groupViewModel.groupInfo;
    var conversationViewModel = Provider.of<ConversationViewModel>(context);
    var conversationInfo = conversationViewModel.conversationInfo!;
    switch (key) {
      case 'group_qrcode':
        return const Icon(Icons.qr_code);
      case 'group_announcement':
        return Container();
      case 'group_remark':
        if (groupInfo != null && groupInfo.remark != null) {
          return Text(groupInfo.remark!);
        } else {
          return Container();
        }
      case 'group_name':
        if (groupInfo != null && groupInfo.name != null) {
          return Text(groupInfo.name!);
        } else {
          return Container();
        }
      case 'nickname':
        if (groupMember != null && groupMember!.alias != null) {
          return Text(groupMember!.alias!);
        } else {
          return Container();
        }
      case 'mute':
        return Switch(
            value: conversationInfo.isSilent,
            onChanged: (enable) {
              conversationViewModel.setConversationSilent(conversationInfo.conversation, enable);
            });
      case 'top':
        return Switch(
            value: conversationInfo.isTop > 0,
            onChanged: (enable) {
              var conversationViewModel = Provider.of<ConversationViewModel>(context);
              conversationViewModel.setConversationTop(conversationInfo.conversation, enable ? 1 : 0);
            });
      case 'favorite':
        return Switch(
            value: _groupViewModel.isFavGroup,
            onChanged: (enable) {
              _groupViewModel.setFavGroup(groupInfo!.target, enable);
            });
      case 'display_name':
        return Switch(
            value: _groupViewModel.isHiddenMemberName,
            onChanged: (enable) {
              _groupViewModel.setHideGroupMemberName(groupInfo!.target, enable);
            });
      default:
        return Container();
    }
  }
}
