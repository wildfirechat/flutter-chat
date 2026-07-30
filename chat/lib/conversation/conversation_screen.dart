import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/conversation/channel_conversation_info_screen.dart';
import 'package:chat/conversation/conversation_appbar_title.dart';
import 'package:chat/conversation/conversation_pane.dart';
import 'package:chat/conversation/group_conversation_info_screen.dart';
import 'package:chat/conversation/single_conversation_info_screen.dart';
import 'package:chat/theme/app_colors.dart';

/// 会话页的手机壳:Scaffold + AppBar,消息区与输入栏在 [ConversationPane] 中。
/// 桌面右栏使用 PcConversationPane,不经过本页。
class ConversationScreen extends StatelessWidget {
  final Conversation conversation;
  final int? toFocusMessageId;

  const ConversationScreen(this.conversation,
      {super.key, this.toFocusMessageId});

  @override
  Widget build(BuildContext context) {
    List<Widget> actions = [];
    if (conversation.conversationType != ConversationType.Chatroom) {
      actions = [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      conversation.conversationType == ConversationType.Single
                          ? SingleConversationInfoScreen(conversation)
                          : conversation.conversationType ==
                                  ConversationType.Channel
                              ? ChannelConversationInfoScreen(conversation)
                              : GroupConversationInfoScreen(conversation)),
            );
          },
          icon: const Icon(Icons.more_horiz_rounded),
        )
      ];
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: context.colors.conversationBg,
      appBar: AppBar(
        title: ConversationAppbarTitle(conversation),
        actions: actions,
      ),
      body: SafeArea(
        bottom: false,
        child:
            ConversationPane(conversation, toFocusMessageId: toFocusMessageId),
      ),
    );
  }
}
