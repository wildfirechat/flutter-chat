import 'package:flutter/material.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/utilities.dart';
import 'package:chat/utils/external_target_utils.dart';
import 'package:chat/utils/online_state_builder.dart';
import 'package:chat/utils/online_state_formatter.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/middle_ellipsis_text.dart';

/// 会话标题组件，支持显示 "对方正在输入..." 和用户在线状态。
class ConversationAppbarTitle extends StatelessWidget {
  final Conversation conversation;

  const ConversationAppbarTitle(this.conversation, {super.key});

  @override
  Widget build(BuildContext context) {
    return Selector4<ConversationViewModel, UserViewModel, GroupViewModel, ChannelViewModel,
        (String? typingStatus, UserInfo? targetUserInfo, GroupInfo? targetGroupInfo, ChannelInfo? targetChannelInfo)>(
      builder: (context, rec, __) {
        final baseTitle = rec.$1 ?? Utilities.conversationTitle(context, conversation, rec.$2, rec.$3, rec.$4);
        if (conversation.conversationType != ConversationType.Single ||
            ExternalTargetUtils.isExternalTarget(conversation.target)) {
          return MiddleEllipsisText(baseTitle);
        }
        return OnlineStateBuilder(
          userId: conversation.target,
          builder: (context, state) {
            final l10n = AppLocalizations.of(context)!;
            final status = OnlineStateFormatter.conversationStatusText(state, l10n);
            if (status == null || status.isEmpty) {
              return MiddleEllipsisText(baseTitle);
            }
            return Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: baseTitle),
                  TextSpan(
                    text: '($status)',
                    style: TextStyle(
                      fontSize: (DefaultTextStyle.of(context).style.fontSize ?? 16) - 2,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        );
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
