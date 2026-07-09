
import 'package:chat/conversation/single_conversation_member_view.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/widget/option_switch_item.dart';
import 'package:chat/widget/section_divider.dart';

import '../contact/pick_user_screen.dart';
import '../pc/pc_platform.dart';
import '../pc/pc_user_card.dart';
import '../search/search_conversation_result_view.dart';
import '../user_info_widget.dart';
import '../viewmodel/conversation_view_model.dart';
import '../viewmodel/user_view_model.dart';
import '../widget/option_button_item.dart';
import '../widget/option_item.dart';
import 'conversation_files_screen.dart';
import 'package:chat/app_navigator.dart';

class SingleConversationInfoScreen extends StatelessWidget {
  const SingleConversationInfoScreen(this.conversation, {super.key});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return Selector<UserViewModel, UserInfo?>(
        builder: (context, userInfo, child) {
          return Scaffold(
            appBar: isDesktopShell
                ? null
                : AppBar(
                    title: Text(AppLocalizations.of(context)!.singleConversationDetails),
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
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
        child: Column(children: [
      if (isDesktopShell) const SizedBox(height: 12.0),
      userInfo != null
          ? SingleConversationMemberView(
              conversation,
              userInfo,
              onUserTap: (userInfo, anchor) {
                // 桌面端点成员弹用户信息卡片(与会话内点头像一致),移动端仍整页打开
                if (isDesktopShell) {
                  showPcUserCard(context: context, anchor: anchor, userId: userInfo.userId);
                } else {
                  openPage(context, UserInfoWidget(userInfo.userId));
                }
              },
              onAddActionTap: () {
                _onAddNewConversationMember(context);
              },
            )
          : Container(),
      const SectionDivider(),
      OptionItem(l10n.searchChatContents, onTap: () {
        pushPage(
          context,
          SearchConversationResultView(
            conversation: conversation,
            keyword: '',
          ),
        );
      }),
      OptionItem(l10n.chatFiles, onTap: () {
        pushPage(context, ConversationFilesScreen(conversation));
      }),
      const SectionDivider(),
      OptionSwitchItem(l10n.muteNotification, conversationInfo.isSilent, (enable) {
        conversationViewModel.setConversationSilent(conversationInfo.conversation, enable);
      }),
      OptionSwitchItem(l10n.stickTop, conversationInfo.isTop > 0, (enable) {
        conversationViewModel.setConversationTop(conversationInfo.conversation, enable ? 1 : 0);
      }),
      const SectionDivider(),
      OptionButtonItem(l10n.clearChatHistory, () {
        _showClearMessageDialog(context, conversation);
      }),
      const SectionDivider(),
    ]));
  }

  void _showClearMessageDialog(BuildContext context, Conversation conversation) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(l10n.clearChatHistory),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                Imclient.clearMessages(conversation).then((value) {
                  Fluttertoast.showToast(msg: l10n.clearLocalMessagesSuccess);
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.clearLocalMessages),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                Imclient.clearRemoteConversationMessage(conversation, () {
                  Fluttertoast.showToast(msg: l10n.clearRemoteMessagesSuccess);
                }, (errorCode) {
                  Fluttertoast.showToast(msg: l10n.clearRemoteMessagesFailed(errorCode.toString()));
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.clearRemoteMessages),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onAddNewConversationMember(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 桌面为居中 Dialog,移动端整页 push
    showPickUserScreen(
      context,
      title: l10n.selectContacts,
      (pickerContext, members) async {
        Navigator.pop(pickerContext);
        if (members.isNotEmpty) {
          Imclient.createGroup(null, null, null, 2, members, (strValue) {
            // 用外层 context(详情页仍挂载):桌面右栏打开新群会话,移动端 push
            openConversation(context, Conversation(conversationType: ConversationType.Group, target: strValue));
          }, (errorCode) {
            Fluttertoast.showToast(msg: l10n.networkError);
          });
        }
      },
      disabledCheckedUsers: [conversation.target],
    );
  }
}
