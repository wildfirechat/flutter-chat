import 'package:flutter/widgets.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';

import 'package:chat/config.dart';
import 'package:chat/utilities.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';

/// 会话解析出来的展示信息。
class ConversationDisplayInfo {
  final String title;
  final String portrait;
  final String defaultPortrait;

  const ConversationDisplayInfo(this.title, this.portrait, this.defaultPortrait);
}

typedef ConversationDisplayBuilder = Widget Function(BuildContext context, ConversationDisplayInfo info);

/// 订阅 User / Group / Channel 三个 ViewModel,把 [Conversation] 解析成标题与头像。
///
/// getUserInfo 等接口先返回本地数据(可能为空),再异步从服务端刷新并通过 EventBus
/// 通知 ViewModel,所以这里必须用 Selector 订阅而不是一次性取值。
class ConversationDisplay extends StatelessWidget {
  final Conversation conversation;
  final ConversationDisplayBuilder builder;

  const ConversationDisplay({super.key, required this.conversation, required this.builder});

  /// 单聊用用户默认头像,群聊用群默认头像,其余(频道/聊天室)用频道默认头像。
  static String defaultPortraitOf(Conversation conversation) =>
      conversation.conversationType == ConversationType.Single
          ? Config.defaultUserPortrait
          : conversation.conversationType == ConversationType.Group
              ? Config.defaultGroupPortrait
              : Config.defaultChannelPortrait;

  @override
  Widget build(BuildContext context) {
    return Selector3<UserViewModel, GroupViewModel, ChannelViewModel, (UserInfo?, GroupInfo?, ChannelInfo?)>(
      selector: (context, userViewModel, groupViewModel, channelViewModel) => (
        conversation.conversationType == ConversationType.Single ? userViewModel.getUserInfo(conversation.target) : null,
        conversation.conversationType == ConversationType.Group ? groupViewModel.getGroupInfo(conversation.target) : null,
        conversation.conversationType == ConversationType.Channel ? channelViewModel.getChannelInfo(conversation.target) : null,
      ),
      builder: (context, rec, child) {
        final portrait = switch (conversation.conversationType) {
          ConversationType.Single => rec.$1?.portrait ?? Config.defaultUserPortrait,
          ConversationType.Group => rec.$2?.portrait ?? Config.defaultGroupPortrait,
          ConversationType.Channel => rec.$3?.portrait ?? Config.defaultChannelPortrait,
          _ => ''
        };
        return builder(
          context,
          ConversationDisplayInfo(
            Utilities.conversationTitle(context, conversation, rec.$1, rec.$2, rec.$3),
            portrait,
            defaultPortraitOf(conversation),
          ),
        );
      },
    );
  }
}
