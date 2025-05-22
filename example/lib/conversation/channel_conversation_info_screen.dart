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
import 'package:wfc_example/conversation/conversation_screen.dart';
import 'package:wfc_example/conversation/single_conversation_member_view.dart';
import 'package:wfc_example/viewmodel/channel_view_model.dart';
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
      OptionButtonItem('取消订阅', () {
        Imclient.clearMessages(conversation).then((value) {
          Fluttertoast.showToast(msg: "TODO 取消订阅");
        });
      }),
      const SectionDivider(),
    ]));
  }
}
