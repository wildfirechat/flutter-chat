import 'package:badges/badges.dart' as badge;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/utilities.dart';
import 'package:wfc_example/viewmodel/conversation_list_view_model.dart';

import '../messages/messages.dart';
import '../ui_model/ui_conversation_info.dart';

class ConversationListWidget extends StatelessWidget {
  const ConversationListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var conversationListViewModel = Provider.of<ConversationListViewModel>(context);
    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
            itemCount: conversationListViewModel.conversationList.length,
            itemBuilder: (context, i) {
              UIConversationInfo info = conversationListViewModel.conversationList[i];
              return ConversationListItem(info);
            }),
      ),
    );
  }
}

class ConversationListItem extends StatefulWidget {
  late final UIConversationInfo uiConversationInfo;

  ConversationListItem(this.uiConversationInfo) : super(key: ValueKey(uiConversationInfo.conversationInfo));

  @override
  State<ConversationListItem> createState() => _ConversationListItemState();
}

class _ConversationListItemState extends State<ConversationListItem> {
  var convTitle = '';
  var convPortrait = '';
  var lastMsgDigest = '';

  @override
  void initState() {
    super.initState();
    widget.uiConversationInfo.titlePortraitAndLastMsg(context).then((onValue) {
      debugPrint('onValue: $onValue');
      setState(() {
        convTitle = onValue.$1;
        convPortrait = onValue.$2;
        lastMsgDigest = onValue.$3;
      });
    }).catchError((error) {
      // Handle error
      debugPrint("Error fetching conversation data: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    var conversationInfo = widget.uiConversationInfo.conversationInfo;
    bool hasDraft = conversationInfo.draft != null && conversationInfo.draft!.isNotEmpty;
    if (conversationInfo.lastMessage != null &&
        conversationInfo.conversation.conversationType != ConversationType.Single &&
        conversationInfo.lastMessage?.fromUser != Imclient.currentUserId) {}

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
                          child: !convPortrait.startsWith('http')
                              ? Image.asset(convPortrait, width: 44.0, height: 44.0)
                              : Image.network(convPortrait, width: 44.0, height: 44.0),
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
                                      child: Text(
                                        hasDraft ? conversationInfo.draft! : lastMsgDigest,
                                        style: const TextStyle(fontSize: 12.0, color: Color(0xffaaaaaa)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
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
          )),
      onTap: () => _toChatPage(context, conversationInfo.conversation),
      onLongPressStart: (details) => _onLongPressed(context, conversationInfo, details.globalPosition),
    );
  }

  void _toChatPage(BuildContext context, Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Messages(conversation)),
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
    var conversationInfo = widget.uiConversationInfo.conversationInfo;
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
