import 'package:flutter/material.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/utilities.dart';
import 'package:chat/utils/external_target_utils.dart';
import 'package:chat/utils/mesh_user_display.dart';
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
    Widget child = Selector4<ConversationViewModel, UserViewModel, GroupViewModel, ChannelViewModel,
        (int typingKind, int typingCount, String? typingUserName, String typingDots, UserInfo? targetUserInfo,
            GroupInfo? targetGroupInfo, ChannelInfo? targetChannelInfo)>(
      builder: (context, rec, __) {
        String? typingStatus;
        if (rec.$1 != 0) {
          final l10n = AppLocalizations.of(context)!;
          final dots = rec.$4;
          if (rec.$1 == 1) {
            typingStatus = '${l10n.peerTyping}$dots';
          } else if (rec.$1 == 2) {
            typingStatus = '${l10n.groupMembersTyping(rec.$2)}$dots';
          } else {
            typingStatus = '${l10n.namedUserTyping(rec.$3 ?? '')}$dots';
          }
        }
        var baseTitle = typingStatus ?? Utilities.conversationTitle(context, conversation, rec.$5, rec.$6, rec.$7);
        // 群组标题后追加当前群人数，对齐 iOS："群名称(人数)"
        if (conversation.conversationType == ConversationType.Group && rec.$6 != null) {
          baseTitle = '$baseTitle(${rec.$6!.memberCount})';
        }
        final isExternal = conversation.conversationType == ConversationType.Single &&
            ExternalTargetUtils.isExternalTarget(conversation.target);

        // 外部域用户的标题需要使用带黄色、小字号域后缀的富文本样式。
        if (typingStatus == null && isExternal && rec.$5 != null) {
          return Text.rich(
            MeshUserDisplay.getReadableNameSpan(
              rec.$5!,
              style: DefaultTextStyle.of(context).style,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        if (conversation.conversationType != ConversationType.Single || isExternal) {
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
        conversationViewModel.typingKind,
        conversationViewModel.typingCount,
        conversationViewModel.typingUserName,
        conversationViewModel.typingDots,
        conversation.conversationType == ConversationType.Single ? userViewModel.getUserInfo(conversation.target) : null,
        conversation.conversationType == ConversationType.Group ? groupViewModel.getGroupInfo(conversation.target) : null,
        conversation.conversationType == ConversationType.Channel ? channelViewModel.getChannelInfo(conversation.target) : null
      ),
    );

    // 移动端标题字号比 AppBar 默认小 2pt
    if (isDesktopShell) return child;
    return DefaultTextStyle.merge(
      style: TextStyle(fontSize: (DefaultTextStyle.of(context).style.fontSize ?? 18) - 2),
      child: child,
    );
  }
}
