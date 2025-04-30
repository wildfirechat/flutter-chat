import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:wfc_example/config.dart';
import 'package:wfc_example/repo/channel_repo.dart';
import 'package:wfc_example/repo/group_repo.dart';
import 'package:wfc_example/repo/user_repo.dart';

class UIConversationInfo {
  ConversationInfo conversationInfo;
  late String portrait;
  late String _title;
  late String lastMessageSenderName;
  late String lastMessageDigest;
  late int updateDt;

  UIConversationInfo(this.conversationInfo) {
    updateDt = conversationInfo.timestamp;
  }

  Future<(String, String)> get titleAndPortrait async {
    if (conversationInfo.conversation.conversationType == ConversationType.Single) {
      var userInfo = await UserRepo.getUserInfo(conversationInfo.conversation.target);
      return (userInfo?.displayName ?? '私聊', userInfo?.portrait ?? Config.defaultUserPortrait);
    } else if (conversationInfo.conversation.conversationType == ConversationType.Group) {
      var groupInfo = await GroupRepo.getGroupInfo(conversationInfo.conversation.target);
      return (groupInfo?.name ?? "群聊", groupInfo?.portrait ?? Config.defaultGroupPortrait);
    } else if (conversationInfo.conversation.conversationType == ConversationType.Channel) {
      var channelInfo = await ChannelRepo.getChannelInfo(conversationInfo.conversation.target);
      return (channelInfo?.name ?? "频道", channelInfo?.portrait ?? Config.defaultChannelPortrait);
    } else {
      return ("会话", "");
    }
  }
}
