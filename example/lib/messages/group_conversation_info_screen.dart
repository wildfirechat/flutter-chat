import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/messages/messages.dart';
import 'package:wfc_example/viewmodel/conversation_view_model.dart';
import 'package:wfc_example/viewmodel/group_conversation_info_view_model.dart';
import 'package:wfc_example/viewmodel/group_view_model.dart';
import 'package:wfc_example/widget/option_button_item.dart';
import 'package:wfc_example/widget/option_item.dart';
import 'package:wfc_example/widget/option_switch_item.dart';
import 'package:wfc_example/widget/SectionDivider.dart';

import '../contact/pick_user_screen.dart';
import '../user_info_widget.dart';
import 'group_conversation_members_view.dart';

class GroupConversationInfoScreen extends StatelessWidget {
  const GroupConversationInfoScreen(this.conversation, {super.key});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GroupConversationInfoViewModel>(
        create: (_) {
          var groupViewModel = GroupConversationInfoViewModel();
          groupViewModel.setup(conversation.target);
          return groupViewModel;
        },
        child: Consumer<GroupConversationInfoViewModel>(
            builder: (context, viewModel, child) => Scaffold(
                  appBar: AppBar(
                    title: const Text('群会话详情'),
                  ),
                  body: SafeArea(
                    child: viewModel.groupMember == null
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : _buildGroupConversationInfoView(context, viewModel, viewModel.groupMember!),
                  ),
                )));
  }

  Widget _buildGroupConversationInfoView(BuildContext context, GroupConversationInfoViewModel groupConversationInfoViewModel, GroupMember groupMember) {
    var groupViewModel = Provider.of<GroupViewModel>(context);
    var conversationViewModel = Provider.of<ConversationViewModel>(context);
    var conversationInfo = conversationViewModel.conversationInfo!;
    var groupInfo = groupViewModel.getGroupInfo(conversation.target);
    return SingleChildScrollView(
        child: Column(children: [
      GroupConversationMembersView(
        conversation,
        onGroupMemberTap: (userInfo) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UserInfoWidget(userInfo.userId)),
          );
        },
        onAddActionTap: () {
          _onAddNewConversationMember(context);
        },
        onRemoveActionTap: () {
          _onRemoveConversationMember(context);
        },
        onShowMoreGroupMemberTap: () {
          // TODO
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => GroupAllMembersWidget(conversation.target, groupMembers, hasPlus, hasMinus)),
          // );
        },
      ),
      const SectionDivider(),
      OptionItem('成员列表', onTap: () {}),
      OptionItem('群聊名称', desc: groupInfo?.name ?? '群聊', onTap: () {}),
      OptionItem('群二维码', rightIcon: Icons.qr_code, onTap: () {}),
      OptionItem('群公告', desc: '占位群公告', onTap: () {}),
      OptionItem('群备注', desc: groupInfo?.remark, onTap: () {}),
      groupMember.type == GroupMemberType.Manager || groupMember.type == GroupMemberType.Owner ? OptionItem('群管理', onTap: () {}) : Container(),
      const SectionDivider(),
      OptionItem('查找聊天内容', onTap: () {}),
      OptionItem('会话文件', onTap: () {}),
      const SectionDivider(),
      OptionSwitchItem('消息免打扰', conversationInfo.isSilent, (enable) {
        conversationViewModel.setConversationSilent(conversationInfo.conversation, enable);
      }),
      OptionSwitchItem('置顶聊天', conversationInfo.isTop > 0, (enable) {
        conversationViewModel.setConversationTop(conversationInfo.conversation, enable ? 1 : 0);
      }),
      OptionSwitchItem('保存到通讯录', groupConversationInfoViewModel.isFavGroup, (enable) {
        groupConversationInfoViewModel.setFavGroup(conversationInfo.conversation.target, enable);
      }),
      const SectionDivider(),
      OptionItem('我在本群的昵称', desc: groupMember.alias, onTap: () {}),
      OptionSwitchItem('显示群成员昵称', !conversationViewModel.isHiddenConversationMemberName, (enable) {
        conversationViewModel.setHideGroupMemberName(conversationInfo.conversation.target, !enable);
      }),
      const SectionDivider(),
      OptionButtonItem('清空聊天记录', () {
        Imclient.clearMessages(conversation).then((value) {
          Fluttertoast.showToast(msg: "清理成功");
        });
      }),
      groupMember.type == GroupMemberType.Owner ? OptionButtonItem('转移群组', () {}) : Container(),
      groupMember.type == GroupMemberType.Owner ? OptionButtonItem('解散群组', () {}) : Container(),
      groupMember.type != GroupMemberType.Owner ? OptionButtonItem('退出群组', () {}) : Container(),
      const SectionDivider(),
    ]));
  }

  void _onRemoveConversationMember(BuildContext context) {
    Imclient.getGroupMembers(conversation.target).then((value) {
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
                        Imclient.kickoffGroupMembers(conversation.target, members, () {
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 100), () {});
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

  void _onAddNewConversationMember(BuildContext context) {
    if (conversation.conversationType == ConversationType.Group) {
      Imclient.getGroupMembers(conversation.target).then((value) {
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
                      Imclient.addGroupMembers(conversation.target, members, () {
                        Navigator.pop(context);
                        Future.delayed(const Duration(milliseconds: 100), () {});
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
                  disabledCheckedUsers: [conversation.target],
                )),
      );
    }
  }
}
