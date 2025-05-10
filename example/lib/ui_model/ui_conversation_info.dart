import 'package:flutter/widgets.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/config.dart';
import 'package:wfc_example/viewmodel/channel_view_model.dart';
import 'package:wfc_example/viewmodel/group_view_model.dart';
import 'package:wfc_example/viewmodel/user_view_model.dart';

class UIConversationInfo {
  ConversationInfo conversationInfo;
  // TODO the following member fields not used now
  String? portrait;
  String? title;
  String? lastMessageSenderName;
  String? lastMessageDigest;
  int? updateDt;

  UIConversationInfo(this.conversationInfo) {
    updateDt = conversationInfo.timestamp;
  }

  Future<(String, String)> titleAndPortrait(BuildContext context) async {
    if (conversationInfo.conversation.conversationType == ConversationType.Single) {
      UserViewModel userViewModel = Provider.of<UserViewModel>(context, listen: false);
      var userInfo = await userViewModel.getUserInfo(conversationInfo.conversation.target);
      return (userInfo?.displayName ?? '私聊', userInfo?.portrait ?? Config.defaultUserPortrait);
    } else if (conversationInfo.conversation.conversationType == ConversationType.Group) {
      GroupViewModel groupViewModel = Provider.of<GroupViewModel>(context, listen: false);
      var groupInfo = await groupViewModel.getGroupInfo(conversationInfo.conversation.target);
      return (groupInfo?.name ?? "群聊", groupInfo?.portrait ?? Config.defaultGroupPortrait);
    } else if (conversationInfo.conversation.conversationType == ConversationType.Channel) {
      ChannelViewModel channelViewModel = Provider.of<ChannelViewModel>(context, listen: false);
      var channelInfo = await channelViewModel.getChannelInfo(conversationInfo.conversation.target);
      return (channelInfo?.name ?? "频道", channelInfo?.portrait ?? Config.defaultChannelPortrait);
    } else {
      return ("会话", "");
    }
  }

  Future<String> lastMsgDigest(BuildContext context) async {
    UserViewModel userViewModel = Provider.of<UserViewModel>(context, listen: false);
    if (conversationInfo.lastMessage == null) {
      return '';
    }
    var userInfoFuture = userViewModel.getUserInfo(conversationInfo.lastMessage!.fromUser,
        groupId: conversationInfo.conversation.conversationType == ConversationType.Group ? conversationInfo.conversation.target : null);

    Future<String> msgDigestFuture = conversationInfo.lastMessage!.content.digest(conversationInfo.lastMessage!);

    final (userInfo, msgDigest) = await (userInfoFuture, msgDigestFuture).wait;
    return '${userInfo == null ? '' : userInfo.getReadableName()}: $msgDigest';
  }

  Future<(String, String, String)> titlePortraitAndLastMsgFuture(BuildContext context) async {
    final (titleAndPortraitRecord, lastMsgDigestStr) = await (titleAndPortrait(context), lastMsgDigest(context)).wait;
    return (titleAndPortraitRecord.$1, titleAndPortraitRecord.$2, lastMsgDigestStr);
  }
}
