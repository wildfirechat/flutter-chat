import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/conversation/channel_conversation_info_screen.dart';
import 'package:chat/conversation/conversation_appbar_title.dart';
import 'package:chat/conversation/conversation_pane.dart';
import 'package:chat/conversation/group_conversation_info_screen.dart';
import 'package:chat/conversation/single_conversation_info_screen.dart';
import 'package:chat/pc/pc_message_input_bar.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/pc/widgets/pc_side_sheet.dart';
import 'package:chat/theme/app_colors.dart';

/// 桌面右栏的会话页:标题栏 + 共享 [ConversationPane](注入桌面输入栏)。
/// 会话信息等二级页通过最近的 Navigator(右栏嵌套 Navigator)打开。
class PcConversationPane extends StatelessWidget {
  final Conversation conversation;
  final int? toFocusMessageId;

  const PcConversationPane(this.conversation,
      {super.key, this.toFocusMessageId});

  /// 会话详情以右侧抽屉呈现(微信 PC 形态),不占满右栏;
  /// 详情内的二级页(成员列表等)经 app_navigator 在右栏打开,抽屉路由随之被清掉。
  void _openConversationInfo(BuildContext context) {
    showPcSideSheet(
      context: context,
      builder: (context) =>
          conversation.conversationType == ConversationType.Single
              ? SingleConversationInfoScreen(conversation)
              : conversation.conversationType == ConversationType.Channel
                  ? ChannelConversationInfoScreen(conversation)
                  : GroupConversationInfoScreen(conversation),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.chatBgDesktop,
      child: Column(
        children: [
          Container(
            height: PcTheme.headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(width: 0.5, color: colors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: PcTheme.paneTitle(context),
                    child: ConversationAppbarTitle(conversation),
                  ),
                ),
                if (conversation.conversationType != ConversationType.Chatroom)
                  HoverBuilder(
                    cursor: SystemMouseCursors.click,
                    builder: (context, hovered) => GestureDetector(
                      onTap: () => _openConversationInfo(context),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 24,
                        color:
                            hovered ? colors.textPrimary : colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 输入栏可拖高,但不能把消息列表挤没:按会话区实际高度给出上限
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => ConversationPane(
                conversation,
                toFocusMessageId: toFocusMessageId,
                inputBar: PcMessageInputBar(
                  maxHeight:
                      constraints.maxHeight * PcTheme.inputBarMaxHeightRatio,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
