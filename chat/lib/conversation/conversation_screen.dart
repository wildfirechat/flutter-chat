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

  /// 是否显示返回键。整页打开时必须有(默认);平板右栏里没有"上一页"可回,
  /// 由 PadHome 传 false 关掉 —— 栏底下垫着占位页,不关的话 AppBar 会自动
  /// 长出一个箭头,点了就退到空栏。
  final bool showBackButton;

  const ConversationScreen(this.conversation,
      {super.key, this.toFocusMessageId, this.showBackButton = true});

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
        automaticallyImplyLeading: showBackButton,
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
