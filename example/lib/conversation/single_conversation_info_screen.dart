
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/conversation/conversation_screen.dart';
import 'package:wfc_example/conversation/single_conversation_member_view.dart';
import 'package:wfc_example/viewmodel/conversation_view_model.dart';
import 'package:wfc_example/viewmodel/user_view_model.dart';
import 'package:wfc_example/widget/option_button_item.dart';
import 'package:wfc_example/widget/option_item.dart';
import 'package:wfc_example/widget/option_switch_item.dart';
import 'package:wfc_example/widget/section_divider.dart';

import '../contact/pick_user_screen.dart';
import '../search/search_conversation_result_view.dart';
import '../user_info_widget.dart';
import 'conversation_files_screen.dart';

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
      OptionItem('查找聊天内容', onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchConversationResultView(
              conversation: conversation,
              keyword: '',
            ),
          ),
        );
      }),
      OptionItem('会话文件', onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationFilesScreen(conversation),
          ),
        );
      }),
      const SectionDivider(),
      OptionSwitchItem('消息免打扰', conversationInfo.isSilent, (enable) {
        conversationViewModel.setConversationSilent(conversationInfo.conversation, enable);
      }),
      OptionSwitchItem('置顶聊天', conversationInfo.isTop > 0, (enable) {
        conversationViewModel.setConversationTop(conversationInfo.conversation, enable ? 1 : 0);
      }),
      const SectionDivider(),
      OptionButtonItem('清空聊天记录', () {
        _showClearMessageDialog(context, conversation);
      }),
      const SectionDivider(),
    ]));
  }

  void _showClearMessageDialog(BuildContext context, Conversation conversation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('清空聊天记录'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                Imclient.clearMessages(conversation).then((value) {
                  Fluttertoast.showToast(msg: "清理本地消息成功");
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('清空本地消息'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                Imclient.clearRemoteConversationMessage(conversation, () {
                  Fluttertoast.showToast(msg: "清理远程消息成功");
                }, (errorCode) {
                  Fluttertoast.showToast(msg: "清理远程消息失败: $errorCode");
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('清空远程消息'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onAddNewConversationMember(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PickUserScreen(
                title: '选择联系人',
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
