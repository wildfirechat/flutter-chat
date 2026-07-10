import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/widget/option_button_item.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/widget/option_switch_item.dart';
import 'package:chat/widget/section_divider.dart';

import '../pc/pc_platform.dart';
import '../search/search_conversation_result_view.dart';
import '../utils/media_url_redirector.dart';
import 'conversation_files_screen.dart';
import 'package:chat/theme/app_colors.dart';

class ChannelConversationInfoScreen extends StatelessWidget {
  const ChannelConversationInfoScreen(this.conversation, {super.key});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return Selector<ChannelViewModel, ChannelInfo?>(
        builder: (context, channelInfo, child) {
          return Scaffold(
            backgroundColor: context.colors.primaryBackground,
            appBar: isDesktopShell
                ? null
                : AppBar(
                    title: Text(AppLocalizations.of(context)!.channelDetails),
                  ),
            body: SafeArea(
              child: _buildSingleConversationInfoView(context, channelInfo),
            ),
          );
        },
        selector: (context, channelViewModel) => channelViewModel.getChannelInfo(conversation.target));
  }

  Widget _buildSingleConversationInfoView(BuildContext context, ChannelInfo? channelInfo) {
    var conversationViewModel = Provider.of<ConversationViewModel>(context);
    var conversationInfo = conversationViewModel.conversationInfo!;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
        child: Column(children: [
      if (isDesktopShell) const SizedBox(height: 12.0),
      channelInfo != null
          ? Container(
              color: context.colors.surface,
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              width: double.infinity,
              child: Column(
                children: [
                  CachedNetworkImage(
                    imageUrl: MediaUrlRedirector.redirect(channelInfo.portrait!),
                    width: 80,
                    height: 80,
                  ),
                  Container(margin: const EdgeInsets.only(top: 10.0, bottom: 10), child: Text(channelInfo.name!))
                ],
              ),
            )
          : Container(
              color: context.colors.surface,
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
      const SectionDivider(),
      Container(
        color: context.colors.surface,
        child: Column(
          children: [
            OptionItem(l10n.searchChatContents, onTap: () {
              pushPage(
                context,
                SearchConversationResultView(
                  conversation: conversation,
                  keyword: '',
                ),
              );
            }),
            OptionItem(l10n.chatFiles, showBottomDivider: false, onTap: () {
              pushPage(context, ConversationFilesScreen(conversation));
            }),
          ],
        ),
      ),
      const SectionDivider(),
      Container(
        color: context.colors.surface,
        child: Column(
          children: [
            OptionSwitchItem(l10n.muteNotification, conversationInfo.isSilent, (enable) {
              conversationViewModel.setConversationSilent(conversationInfo.conversation, enable);
            }),
            OptionSwitchItem(l10n.stickTop, conversationInfo.isTop > 0, showBottomDivider: false, (enable) {
              conversationViewModel.setConversationTop(conversationInfo.conversation, enable ? 1 : 0);
            }),
          ],
        ),
      ),
      const SectionDivider(),
      Container(
        color: context.colors.surface,
        child: Column(
          children: [
            OptionButtonItem(l10n.clearChatHistory, () {
              _showClearMessageDialog(context, conversation);
            }, showBottomDivider: true),
            OptionButtonItem(l10n.unsubscribeChannel, () {
              _showUnsubscribeChannelConfirmDialog(context);
            }, showBottomDivider: false),
          ],
        ),
      ),
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

  void _showUnsubscribeChannelConfirmDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.unsubscribeChannel),
          content: Text('${l10n.unsubscribeChannel}？${l10n.confirm}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleUnsubscribeChannel(context);
              },
              child: Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _handleUnsubscribeChannel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 取消订阅频道 - 清除本地消息后返回列表
    final navigator = Navigator.of(context);
    Imclient.listenChannel(conversation.target, false, () {
      Fluttertoast.showToast(msg: l10n.unsubscribeChannelSuccess);
      Future.delayed(const Duration(milliseconds: 200), () {
        // 返回到会话列表（需要pop两层：详情页 -> 会话页 -> 会话列表）
        navigator.popUntil((r) => r.isFirst);
      });
    }, (int error) {});
  }
}
