import 'package:flutter/material.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/utilities.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';

class ConversationAppbarTitle extends StatelessWidget {
  final Conversation conversation;

  const ConversationAppbarTitle(this.conversation, {super.key});

  @override
  Widget build(BuildContext context) {
    return Selector4<ConversationViewModel, UserViewModel, GroupViewModel, ChannelViewModel,
        (String? typingStatus, UserInfo? targetUserInfo, GroupInfo? targetGroupInfo, ChannelInfo? targetChannelInfo)>(
      builder: (_, rec, __) {
        return Text(rec.$1 ?? Utilities.conversationTitle(conversation, rec.$2, rec.$3, rec.$4));
      },
      selector: (context, conversationViewModel, userViewModel, groupViewModel, channelViewModel) => (
        conversationViewModel.conversationTypingStatus,
        conversation.conversationType == ConversationType.Single ? userViewModel.getUserInfo(conversation.target) : null,
        conversation.conversationType == ConversationType.Group ? groupViewModel.getGroupInfo(conversation.target) : null,
        conversation.conversationType == ConversationType.Channel ? channelViewModel.getChannelInfo(conversation.target) : null
      ),
    );
  }
}
