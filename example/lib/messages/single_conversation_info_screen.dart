import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/messages/messages.dart';
import 'package:wfc_example/messages/single_conversation_member_view.dart';
import 'package:wfc_example/viewmodel/conversation_view_model.dart';
import 'package:wfc_example/viewmodel/group_conversation_info_view_model.dart';
import 'package:wfc_example/viewmodel/user_view_model.dart';
import 'package:wfc_example/widget/OptionButtonItem.dart';
import 'package:wfc_example/widget/OptionItem.dart';
import 'package:wfc_example/widget/OptionSwitchItem.dart';
import 'package:wfc_example/widget/SectionDivider.dart';

import '../contact/pick_user_screen.dart';
import '../user_info_widget.dart';
import 'group_conversation_members_view.dart';

class SingleConversationInfoScreen extends StatelessWidget {
  const SingleConversationInfoScreen(this.conversation, {super.key});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    var future = Imclient.getUserInfo(conversation.target);
    return FutureBuilder<UserInfo?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('单聊会话详情'),
            ),
            body: SafeArea(
              child: _buildSingleConversationInfoView(context, snapshot.data!),
            ),
          );
        } else {
          return Scaffold(
            appBar: AppBar(
              title: const Text('单聊会话详情'),
            ),
            body: const SafeArea(
                child: Center(
              child: CircularProgressIndicator(),
            )),
          );
        }
      },
    );
  }

  Widget _buildSingleConversationInfoView(BuildContext context, UserInfo userInfo) {
    var conversationViewModel = Provider.of<ConversationViewModel>(context);
    var conversationInfo = conversationViewModel.conversationInfo!;
    return SingleChildScrollView(
        child: Column(children: [
      SingleConversationMemberView(
        conversation,
        userInfo,
        onUserTap: (userInfo) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UserInfoWidget(userInfo.userId)),
          );
        },
        onAddActionTap: () {
          _onPlusItemClicked(context);
        },
      ),
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

  void _onMinusItemClicked(BuildContext context) {
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

  void _onPlusItemClicked(BuildContext context) {
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
