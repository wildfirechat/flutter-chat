import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/conversation/conversation_screen.dart';
import 'package:wfc_example/conversation/single_conversation_member_view.dart';
import 'package:wfc_example/viewmodel/conversation_view_model.dart';
import 'package:wfc_example/viewmodel/group_conversation_info_view_model.dart';
import 'package:wfc_example/viewmodel/user_view_model.dart';
import 'package:wfc_example/widget/option_button_item.dart';
import 'package:wfc_example/widget/option_item.dart';
import 'package:wfc_example/widget/option_switch_item.dart';
import 'package:wfc_example/widget/section_divider.dart';

import '../contact/pick_user_screen.dart';
import '../user_info_widget.dart';
import 'group_conversation_info_members_view.dart';

class SingleConversationInfoScreen extends StatelessWidget {
  const SingleConversationInfoScreen(this.conversation, {super.key});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return Selector<UserViewModel, UserInfo?>(
        builder: (context, userInfo, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('单聊会话详情'),
            ),
            body: SafeArea(
              child: _buildSingleConversationInfoView(context, userInfo),
            ),
          );
        },
        selector: (context, userViewModel) => userViewModel.getUserInfo(conversation.target));
  }

  Widget _buildSingleConversationInfoView(BuildContext context, UserInfo? userInfo) {
    var conversationViewModel = Provider.of<ConversationViewModel>(context);
    var conversationInfo = conversationViewModel.conversationInfo!;
    return SingleChildScrollView(
        child: Column(children: [
      userInfo != null
          ? SingleConversationMemberView(
              conversation,
              userInfo,
              onUserTap: (userInfo) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserInfoWidget(userInfo.userId)),
                );
              },
              onAddActionTap: () {
                _onAddNewConversationMember(context);
              },
            )
          : Container(),
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
      const SectionDivider(),
      OptionButtonItem('清空聊天记录', () {
        Imclient.clearMessages(conversation).then((value) {
          Fluttertoast.showToast(msg: "清理成功");
        });
      }),
      const SectionDivider(),
    ]));
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
                          MaterialPageRoute(builder: (context) => ConversationScreen(Conversation(conversationType: ConversationType.Group, target: strValue))),
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
