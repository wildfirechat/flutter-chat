import 'dart:async';

import 'package:badges/badges.dart' as badge;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/config.dart';
import 'package:wfc_example/utilities.dart';
import 'package:wfc_example/viewmodel/channel_view_model.dart';
import 'package:wfc_example/viewmodel/conversation_list_view_model.dart';
import 'package:wfc_example/viewmodel/group_view_model.dart';
import 'package:wfc_example/viewmodel/user_view_model.dart';

import '../messages/messages_screen.dart';

class ConversationListWidget extends StatelessWidget {
  const ConversationListWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var conversationListViewModel = Provider.of<ConversationListViewModel>(context);
    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
            itemCount: conversationListViewModel.conversationList.length,
            itemBuilder: (context, i) {
              ConversationInfo info = conversationListViewModel.conversationList[i];
              String? portrait;
              String? convTitle;
              if (info.conversation.conversationType == ConversationType.Single) {
                return Selector<UserViewModel, UserInfo?>(
                    selector: (_, userViewModel) => userViewModel.getUserInfo(info.conversation.target),
                    builder: (_, userInfo, __) {
                      if (userInfo != null && userInfo.portrait != null && userInfo.portrait!.isNotEmpty) {
                        portrait = userInfo.portrait!;
                        convTitle = userInfo.displayName!;
                      } else {
                        convTitle = '私聊';
                        portrait = Config.defaultUserPortrait;
                      }

                      return ConversationListItem(info, convTitle!, portrait!);
                    });
              } else if (info.conversation.conversationType == ConversationType.Group) {
                return Selector<GroupViewModel, GroupInfo?>(
                    selector: (_, groupViewModel) => groupViewModel.getGroupInfo(info.conversation.target),
                    builder: (_, groupInfo, __) {
                      if (groupInfo != null && groupInfo.portrait != null && groupInfo.portrait!.isNotEmpty) {
                        portrait = groupInfo.portrait!;
                        convTitle = groupInfo.name!;
                      } else {
                        convTitle = '群聊';
                        portrait = Config.defaultGroupPortrait;
                      }
                      return ConversationListItem(info, convTitle!, portrait!);
                    });
              } else if (info.conversation.conversationType == ConversationType.Channel) {
                return Selector<ChannelViewModel, ChannelInfo?>(
                    selector: (_, channelViewModel) => channelViewModel.getChannelInfo(info.conversation.target),
                    builder: (_, channelInfo, __) {
                      if (channelInfo != null && channelInfo.portrait != null && channelInfo.portrait!.isNotEmpty) {
                        portrait = channelInfo.portrait!;
                        convTitle = channelInfo.name!;
                      } else {
                        convTitle = '频道';
                        portrait = Config.defaultChannelPortrait;
                      }
                      return ConversationListItem(info, convTitle!, portrait!);
                    });
              } else {
                convTitle = '未知会话';
                return Text(convTitle);
              }
            }),
      ),
    );
  }
}

class ConversationListItem extends StatelessWidget {
  late final ConversationInfo conversationInfo;
  late final String convTitle;
  late final String portrait;

  ConversationListItem(this.conversationInfo, this.convTitle, this.portrait) : super(key: ValueKey(conversationInfo));

  @override
  Widget build(BuildContext context) {
    bool hasDraft = conversationInfo.draft != null && conversationInfo.draft!.isNotEmpty;
    UserInfo? senderInfo;
    if (conversationInfo.lastMessage != null && conversationInfo.conversation.conversationType != ConversationType.Single && conversationInfo.lastMessage?.fromUser != Imclient.currentUserId) {
      UserViewModel userViewModel = Provider.of<UserViewModel>(context, listen: false);
      senderInfo = userViewModel.getUserInfo(conversationInfo.lastMessage!.fromUser, groupId: conversationInfo.conversation.conversationType == ConversationType.Group ? conversationInfo.conversation.target : null);
    }

    String? senderName = senderInfo?.getReadableName();
    Future<String>? msgDigest = conversationInfo.lastMessage?.content.digest(conversationInfo.lastMessage!);

    return GestureDetector(
      child: Container(
        color: conversationInfo.isTop > 0 ? CupertinoColors.secondarySystemBackground : CupertinoColors.systemBackground,
        child: Column(
          children: <Widget>[
            Container(
              height: 64.0,
              margin: const EdgeInsets.only(left: 15),
              child: Row(
                children: <Widget>[
                  badge.Badge(
                      showBadge: conversationInfo.unreadCount.unread > 0,
                      badgeContent: Text(conversationInfo.isSilent ? '' : '${conversationInfo.unreadCount.unread}'),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: !portrait.startsWith('http') ? Image.asset(portrait, width: 44.0, height: 44.0) : Image.network(portrait, width: 44.0, height: 44.0),
                      )),
                  Expanded(
                      child: Container(
                          height: 48.0,
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.only(left: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                convTitle,
                                style: const TextStyle(fontSize: 15.0),
                                maxLines: 1,
                              ),
                              Container(
                                height: 2,
                              ),
                              Row(
                                children: [
                                  _messageStatusIcon(),
                                  hasDraft
                                      ? const Text(
                                          "[草稿]",
                                          style: TextStyle(fontSize: 12.0, color: Colors.red),
                                        )
                                      : Container(),
                                  Expanded(
                                      child: FutureBuilder<String>(
                                          future: msgDigest,
                                          builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                                            String digestStr = snapshot.data ?? '';
                                            return Text(
                                              hasDraft ? conversationInfo.draft! : (senderName == null ? digestStr : '$senderName: $digestStr'),
                                              style: const TextStyle(fontSize: 12.0, color: Color(0xffaaaaaa)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          })),
                                ],
                              ),
                            ],
                          ))),
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0.0, 15.0, 15.0, 0.0),
                        child: Text(
                          Utilities.formatTime(conversationInfo.timestamp),
                          style: const TextStyle(
                            fontSize: 10.0,
                            color: Color(0xffaaaaaa),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0.0, 5.0, 15.0, 0.0),
                        child: conversationInfo.isSilent
                            ? Image.asset(
                                'assets/images/conversation_mute.png',
                                width: 10,
                                height: 10,
                              )
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
              height: 0.5,
              color: const Color(0xffebebeb),
            ),
          ],
        ),
      ),
      onTap: () => _toChatPage(context, conversationInfo.conversation),
      onLongPressStart: (details) => _onLongPressed(context, conversationInfo, details.globalPosition),
    );
  }

  void _toChatPage(BuildContext context, Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MessagesScreen(conversation)),
    ).then((value) {
      // _loadConversation();
    });
  }

  void _onLongPressed(BuildContext context, ConversationInfo conversationInfo, Offset position) {
    List<PopupMenuItem> items = [
      const PopupMenuItem(
        value: 'delete',
        child: Text('删除会话'),
      )
    ];

    if (conversationInfo.isTop > 0) {
      items.add(const PopupMenuItem(
        value: 'untop',
        child: Text('取消置顶'),
      ));
    } else {
      items.add(const PopupMenuItem(
        value: 'top',
        child: Text('置顶'),
      ));
    }

    if (conversationInfo.unreadCount.unread + conversationInfo.unreadCount.unreadMention + conversationInfo.unreadCount.unreadMentionAll > 0) {
      items.add(const PopupMenuItem(
        value: 'clear_unread',
        child: Text('清除未读'),
      ));
    } else {
      items.add(const PopupMenuItem(
        value: 'set_unread',
        child: Text('设为未读'),
      ));
    }

    var conversationListViewModel = Provider.of<ConversationListViewModel>(context, listen: false);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: items,
    ).then((selected) {
      if (selected != null) {
        switch (selected) {
          case "delete":
            conversationListViewModel.removeConversation(conversationInfo.conversation);
            break;
          case "top":
            conversationListViewModel.setConversationTop(conversationInfo.conversation, 1);
            break;
          case "untop":
            conversationListViewModel.setConversationTop(conversationInfo.conversation, 0);
            break;
          case "clear_unread":
            conversationListViewModel.clearConversationUnreadStatus(conversationInfo.conversation);
            break;
          case "set_unread":
            conversationListViewModel.markConversationAsUnRead(conversationInfo.conversation);
            break;
        }
      }
    });
  }

  Widget _messageStatusIcon() {
    if (conversationInfo.lastMessage != null) {
      if (conversationInfo.lastMessage!.status == MessageStatus.Message_Status_Sending) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
          child: Image.asset(
            "assets/images/conversation_msg_sending.png",
            width: 16,
            height: 16,
          ),
        );
      } else if (conversationInfo.lastMessage!.status == MessageStatus.Message_Status_Send_Failure) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
          child: Image.asset(
            "assets/images/conversation_msg_failure.png",
            width: 16,
            height: 16,
          ),
        );
      }
    }

    return Container();
  }
}
