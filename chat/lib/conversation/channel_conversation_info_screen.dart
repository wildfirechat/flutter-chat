import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/conversation/single_conversation_member_view.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/viewmodel/group_conversation_info_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/option_button_item.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/widget/option_switch_item.dart';
import 'package:chat/widget/section_divider.dart';

import '../contact/pick_user_screen.dart';
import '../search/search_conversation_result_view.dart';
import '../user_info_widget.dart';
import 'conversation_files_screen.dart';
import 'group_conversation_info_members_view.dart';

class ChannelConversationInfoScreen extends StatelessWidget {
  const ChannelConversationInfoScreen(this.conversation, {super.key});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return Selector<ChannelViewModel, ChannelInfo?>(
        builder: (context, channelInfo, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('频道详情'),
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
    return SingleChildScrollView(
        child: Column(children: [
      channelInfo != null
          ? Column(
              children: [
                CachedNetworkImage(
                  imageUrl: channelInfo.portrait!,
                  width: 80,
                  height: 80,
                ),
                Container(margin: const EdgeInsets.only(top: 10.0, bottom: 10), child: Text(channelInfo.name!))
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
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
      OptionButtonItem('取消订阅', () {
        Imclient.clearMessages(conversation).then((value) {
          Fluttertoast.showToast(msg: "TODO 取消订阅");
        });
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
}
