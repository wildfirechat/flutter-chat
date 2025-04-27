import 'dart:async';

import 'package:badges/badges.dart' as badge;
import 'package:event_bus/event_bus.dart';
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
import 'package:wfc_example/viewmodel/conversation_list_view_model.dart';

import '../cache.dart';
import '../messages/messages_screen.dart';

class ConversationListWidget extends StatelessWidget {
  ConversationListWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var conversationListViewModel = Provider.of<ConversationListViewModel>(context);
    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
            itemCount: conversationListViewModel.conversationList.length,
            itemBuilder: /*1*/ (context, i) {
              ConversationInfo info = conversationListViewModel.conversationList[i];
              return _row(context, info, i);
            }),
      ),
    );
  }

  Widget _row(BuildContext context, ConversationInfo conversationInfo, int index) {
    return ConversationListItem(
      conversationInfo,
      index,
      longPressedCallback: _onLongPressed,
      conversationPressedCallback: (conversationInfo) {
        _toChatPage(context, conversationInfo.conversation);
      },
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

  void _onLongPressed(BuildContext context, ConversationInfo conversationInfo, int index, Offset position, ConversationListViewModel conversationListViewModel) {
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
}

typedef OnLongPressedCallback = void Function(BuildContext context, ConversationInfo conversationInfo, int index, Offset position, ConversationListViewModel conversationListViewModel);
typedef OnConversationPressedCallback = void Function(ConversationInfo conversationInfo);

class ConversationListItem extends StatefulWidget {
  late final ConversationInfo conversationInfo;
  final int index;
  final OnLongPressedCallback longPressedCallback;
  final OnConversationPressedCallback conversationPressedCallback;

  ConversationListItem(this.conversationInfo, this.index, {required this.longPressedCallback, required this.conversationPressedCallback}) : super(key: ValueKey(conversationInfo));

  @override
  State<StatefulWidget> createState() => ConversationListItemState();
}

class ConversationListItemState extends State<ConversationListItem> {
  UserInfo? userInfo;
  UserInfo? senderInfo;
  GroupInfo? groupInfo;
  ChannelInfo? channelInfo;

  UserInfo? fromUser;

  String? digest = "";

  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<ConversationDraftUpdatedEvent> _draftUpdatedSubscription;
  late StreamSubscription<ConversationSilentUpdatedEvent> _silentUpdatedSubscription;
  late StreamSubscription<ConversationTopUpdatedEvent> _topUpdatedSubscription;
  StreamSubscription<SendMessageSuccessEvent>? _sendMsgSuccessSubscription;
  StreamSubscription<SendMessageFailureEvent>? _sendMsgFailureSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.conversationInfo.conversation.conversationType == ConversationType.Single) {
      userInfo = Cache.getUserInfo(widget.conversationInfo.conversation.target);
      Imclient.getUserInfo(widget.conversationInfo.conversation.target).then((value) {
        if (value != null && value != userInfo && value.userId == widget.conversationInfo.conversation.target) {
          Cache.putUserInfo(value);
          if (mounted) {
            setState(() {
              userInfo = value;
            });
          }
        }
      });
    } else if (widget.conversationInfo.conversation.conversationType == ConversationType.Group) {
      groupInfo = Cache.getGroupInfo(widget.conversationInfo.conversation.target);
      Imclient.getGroupInfo(widget.conversationInfo.conversation.target).then((value) {
        if (value != null && value != groupInfo && value.target == widget.conversationInfo.conversation.target) {
          Cache.putGroupInfo(value);
          if (mounted) {
            setState(() {
              groupInfo = value;
            });
          }
        }
      });
    } else if (widget.conversationInfo.conversation.conversationType == ConversationType.Channel) {
      Imclient.getChannelInfo(widget.conversationInfo.conversation.target).then((value) {
        channelInfo = Cache.getChannelInfo(widget.conversationInfo.conversation.target);
        if (value != null && value != channelInfo && value.channelId == widget.conversationInfo.conversation.target) {
          Cache.putChannelInfo(value);
          if (mounted) {
            setState(() {
              channelInfo = channelInfo;
            });
          }
        }
      });
    }

    if (widget.conversationInfo.lastMessage != null) {
      digest = Cache.getConversationDigest(widget.conversationInfo.conversation);
      widget.conversationInfo.lastMessage!.content.digest(widget.conversationInfo.lastMessage!).then((value) {
        if (digest != value) {
          Cache.putConversationDigest(widget.conversationInfo.conversation, value);
          if (mounted) {
            setState(() {
              digest = value;
            });
          }
        }
      });

      if (widget.conversationInfo.lastMessage!.fromUser != Imclient.currentUserId) {
        String? groupId = widget.conversationInfo.conversation.conversationType == ConversationType.Group ? widget.conversationInfo.conversation.target : null;
        Imclient.getUserInfo(widget.conversationInfo.lastMessage!.fromUser, groupId: groupId).then((value) {
          setState(() {
            senderInfo = value;
          });
        });
      }
    }

    _draftUpdatedSubscription = _eventBus.on<ConversationDraftUpdatedEvent>().listen((event) {
      if (event.conversation == widget.conversationInfo.conversation) {
        setState(() {
          widget.conversationInfo.draft = event.draft;
        });
      }
    });
    _silentUpdatedSubscription = _eventBus.on<ConversationSilentUpdatedEvent>().listen((event) {
      if (event.conversation == widget.conversationInfo.conversation) {
        setState(() {
          widget.conversationInfo.isSilent = event.silent;
        });
      }
    });
    _topUpdatedSubscription = _eventBus.on<ConversationTopUpdatedEvent>().listen((event) {
      if (event.conversation == widget.conversationInfo.conversation) {
        setState(() {
          widget.conversationInfo.isTop = event.top;
        });
      }
    });
    if (widget.conversationInfo.lastMessage != null && widget.conversationInfo.lastMessage!.status == MessageStatus.Message_Status_Sending) {
      _sendMsgSuccessSubscription = _eventBus.on<SendMessageSuccessEvent>().listen((event) {
        if (event.messageId == widget.conversationInfo.lastMessage?.messageId) {
          setState(() {
            widget.conversationInfo.lastMessage!.messageUid = event.messageUid;
            widget.conversationInfo.lastMessage!.serverTime = event.timestamp;
            widget.conversationInfo.lastMessage!.status = MessageStatus.Message_Status_Sent;
            _sendMsgSuccessSubscription?.cancel();
            _sendMsgSuccessSubscription = null;
            _sendMsgFailureSubscription?.cancel();
            _sendMsgFailureSubscription = null;
          });
        }
      });
      _sendMsgFailureSubscription = _eventBus.on<SendMessageFailureEvent>().listen((event) {
        setState(() {
          widget.conversationInfo.lastMessage!.status = MessageStatus.Message_Status_Send_Failure;
          _sendMsgSuccessSubscription?.cancel();
          _sendMsgSuccessSubscription = null;
          _sendMsgFailureSubscription?.cancel();
          _sendMsgFailureSubscription = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String? portrait;
    String? localPortrait;
    String? convTitle;
    var conversationListViewModel = Provider.of<ConversationListViewModel>(context, listen: false);
    if (widget.conversationInfo.conversation.conversationType == ConversationType.Single) {
      if (userInfo != null && userInfo!.portrait != null && userInfo!.portrait!.isNotEmpty) {
        portrait = userInfo!.portrait!;
        convTitle = userInfo!.displayName!;
      } else {
        convTitle = '私聊';
      }
      localPortrait = Config.defaultUserPortrait;
    } else if (widget.conversationInfo.conversation.conversationType == ConversationType.Group) {
      convTitle = '群聊';
      if (groupInfo != null) {
        if (groupInfo!.portrait != null && groupInfo!.portrait!.isNotEmpty) {
          portrait = groupInfo!.portrait!;
        }
        if (groupInfo!.name != null && groupInfo!.name!.isNotEmpty) {
          convTitle = groupInfo!.name!;
        }
      }
      localPortrait = Config.defaultGroupPortrait;
    } else if (widget.conversationInfo.conversation.conversationType == ConversationType.Channel) {
      if (channelInfo != null && channelInfo!.portrait != null && channelInfo!.portrait!.isNotEmpty) {
        portrait = channelInfo!.portrait!;
        convTitle = channelInfo!.name!;
      } else {
        convTitle = '频道';
      }
      localPortrait = Config.defaultChannelPortrait;
    }

    bool hasDraft = widget.conversationInfo.draft != null && widget.conversationInfo.draft!.isNotEmpty;
    String? senderName = senderInfo?.getReadableName();

    return GestureDetector(
      child: Container(
        color: widget.conversationInfo.isTop > 0 ? CupertinoColors.secondarySystemBackground : CupertinoColors.systemBackground,
        child: Column(
          children: <Widget>[
            Container(
              height: 64.0,
              margin: const EdgeInsets.only(left: 15),
              child: Row(
                children: <Widget>[
                  badge.Badge(
                      showBadge: widget.conversationInfo.unreadCount.unread > 0,
                      badgeContent: Text(widget.conversationInfo.isSilent ? '' : '${widget.conversationInfo.unreadCount.unread}'),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: portrait == null ? Image.asset(localPortrait!, width: 44.0, height: 44.0) : Image.network(portrait, width: 44.0, height: 44.0),
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
                                '$convTitle',
                                style: const TextStyle(fontSize: 15.0),
                                maxLines: 1,
                              ),
                              Container(
                                height: 2,
                              ),
                              Row(
                                children: [
                                  _getMessageStatusIcon(),
                                  hasDraft
                                      ? const Text(
                                          "[草稿]",
                                          style: TextStyle(fontSize: 12.0, color: Colors.red),
                                        )
                                      : Container(),
                                  Expanded(
                                      child: Text(
                                    hasDraft ? widget.conversationInfo.draft! : (senderName == null ? '$digest' : '$senderName: $digest'),
                                    style: const TextStyle(fontSize: 12.0, color: Color(0xffaaaaaa)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )),
                                ],
                              ),
                            ],
                          ))),
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0.0, 15.0, 15.0, 0.0),
                        child: Text(
                          Utilities.formatTime(widget.conversationInfo.timestamp),
                          style: const TextStyle(
                            fontSize: 10.0,
                            color: Color(0xffaaaaaa),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0.0, 5.0, 15.0, 0.0),
                        child: widget.conversationInfo.isSilent
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
      onTap: () => widget.conversationPressedCallback(widget.conversationInfo),
      onLongPressStart: (details) => widget.longPressedCallback(context, widget.conversationInfo, widget.index, details.globalPosition, conversationListViewModel),
    );
  }

  Widget _getMessageStatusIcon() {
    if (widget.conversationInfo.lastMessage != null) {
      if (widget.conversationInfo.lastMessage!.status == MessageStatus.Message_Status_Sending) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
          child: Image.asset(
            "assets/images/conversation_msg_sending.png",
            width: 16,
            height: 16,
          ),
        );
      } else if (widget.conversationInfo.lastMessage!.status == MessageStatus.Message_Status_Send_Failure) {
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

  @override
  void dispose() {
    _draftUpdatedSubscription.cancel();
    _topUpdatedSubscription.cancel();
    _silentUpdatedSubscription.cancel();
    _sendMsgSuccessSubscription?.cancel();
    _sendMsgFailureSubscription?.cancel();
    super.dispose();
  }
}
