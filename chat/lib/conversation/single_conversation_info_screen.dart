
import 'package:chat/conversation/single_conversation_member_view.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:chat/widget/option_switch_item.dart';
import 'package:chat/widget/section_divider.dart';

import '../contact/pick_user_screen.dart';
import '../pc/pc_platform.dart';
import '../search/search_conversation_result_view.dart';
import '../user_info_widget.dart';
import '../viewmodel/conversation_view_model.dart';
import '../viewmodel/user_view_model.dart';
import '../widget/option_button_item.dart';
import '../widget/option_item.dart';
import 'conversation_files_screen.dart';
import 'conversation_screen.dart';

class SingleConversationInfoScreen extends StatelessWidget {
  const SingleConversationInfoScreen(this.conversation, {this.onOpenPage, super.key});

  final Conversation conversation;
  /// 桌面端用于在右栏打开二级页面；手机端可忽略。
  final void Function(Widget page)? onOpenPage;

  void _openPage(BuildContext context, Widget page) {
    if (isDesktopShell && onOpenPage != null) {
      Navigator.pop(context); // 关闭侧抽屉
      onOpenPage!(page);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<UserViewModel, UserInfo?>(
        builder: (context, userInfo, child) {
          return Scaffold(
            appBar: AppBar(
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
      userInfo != null
          ? SingleConversationMemberView(
              conversation,
              userInfo,
              onUserTap: (userInfo) {
                _openPage(context, UserInfoWidget(userInfo.userId, onOpenPage: onOpenPage));
              },
              onAddActionTap: () {
                _onAddNewConversationMember(context);
              },
            )
          : Container(),
      const SectionDivider(),
      OptionItem(l10n.searchChatContents, onTap: () {
        _openPage(
          context,
          SearchConversationResultView(
            conversation: conversation,
            keyword: '',
          ),
        );
      }),
      OptionItem(l10n.chatFiles, onTap: () {
        _openPage(context, ConversationFilesScreen(conversation));
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
    _openPage(
      context,
      PickUserScreen(
        title: l10n.selectContacts,
        (context, members) async {
          Navigator.pop(context);
          if (members.isNotEmpty) {
            Imclient.createGroup(null, null, null, 2, members, (strValue) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => ConversationScreen(Conversation(conversationType: ConversationType.Group, target: strValue))),
              );
            }, (errorCode) {
              Fluttertoast.showToast(msg: l10n.networkError);
            });
          }
        },
        disabledCheckedUsers: [conversation.target],
      ),
    );
  }
}
