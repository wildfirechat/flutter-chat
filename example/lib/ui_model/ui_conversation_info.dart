import 'package:flutter/widgets.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:wfc_example/config.dart';
import 'package:wfc_example/repo/channel_repo.dart';
import 'package:wfc_example/repo/group_repo.dart';
import 'package:wfc_example/repo/user_repo.dart';

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

  Future<(String, String)> _titleAndPortrait(BuildContext context) async {
    if (conversationInfo.conversation.conversationType == ConversationType.Single) {
      var userInfo = await UserRepo.getUserInfo(conversationInfo.conversation.target);
      return (userInfo?.friendAlias ?? userInfo?.displayName ?? '私聊', userInfo?.portrait ?? Config.defaultUserPortrait);
    } else if (conversationInfo.conversation.conversationType == ConversationType.Group) {
      var groupInfo = await GroupRepo.getGroupInfo(conversationInfo.conversation.target);
      return (groupInfo?.remark ?? groupInfo?.name ?? "群聊", groupInfo?.portrait ?? Config.defaultGroupPortrait);
    } else if (conversationInfo.conversation.conversationType == ConversationType.Channel) {
      var channelInfo = await ChannelRepo.getChannelInfo(conversationInfo.conversation.target);
      return (channelInfo?.name ?? "频道", channelInfo?.portrait ?? Config.defaultChannelPortrait);
    } else {
      return ("会话", "");
    }
  }

  Future<String> _lastMsgDigest(BuildContext context) async {
    if (conversationInfo.lastMessage == null) {
      return '';
    }
    var userInfoFuture = UserRepo.getUserInfo(conversationInfo.lastMessage!.fromUser,
        groupId: conversationInfo.conversation.conversationType == ConversationType.Group ? conversationInfo.conversation.target : null);

    Future<String> msgDigestFuture = conversationInfo.lastMessage!.content.digest(conversationInfo.lastMessage!);

    final (userInfo, msgDigest) = await (userInfoFuture, msgDigestFuture).wait;
    return '${userInfo == null ? '' : userInfo.getReadableName()}: $msgDigest';
  }

  Future<(String, String, String)> titlePortraitAndLastMsg(BuildContext context) async {
    final (titleAndPortraitRecord, lastMsgDigestStr) = await (_titleAndPortrait(context), _lastMsgDigest(context)).wait;
    return (titleAndPortraitRecord.$1, titleAndPortraitRecord.$2, lastMsgDigestStr);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UIConversationInfo && runtimeType == other.runtimeType && conversationInfo == other.conversationInfo;

  @override
  int get hashCode => conversationInfo.hashCode;
}
