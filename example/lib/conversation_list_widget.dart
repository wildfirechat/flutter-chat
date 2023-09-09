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
import 'package:wfc_example/config.dart';
import 'package:wfc_example/utilities.dart';

import 'cache.dart';
import 'messages/messages_screen.dart';

// ignore: must_be_immutable
class ConversationListWidget extends StatefulWidget {
  Function(int unreadCount) unreadCountCallback;

  ConversationListWidget(this.unreadCountCallback, {Key? key}) : super(key: key);

  @override
  ConversationListWidgetState createState() => ConversationListWidgetState();
}

class ConversationListWidgetState extends State<ConversationListWidget> {
  List<ConversationInfo> conversationInfoList = [];
  late StreamSubscription<ConnectionStatusChangedEvent> _connectionStatusSubscription;
  late StreamSubscription<ReceiveMessagesEvent> _receiveMessageSubscription;
  late StreamSubscription<UserSettingUpdatedEvent> _userSettingUpdatedSubscription;
  late StreamSubscription<RecallMessageEvent> _recallMessageSubscription;
  late StreamSubscription<DeleteMessageEvent> _deleteMessageSubscription;
  late StreamSubscription<ClearConversationUnreadEvent> _clearConversationUnreadSubscription;
  late StreamSubscription<ClearConversationsUnreadEvent> _clearConversationsUnreadSubscription;
  late StreamSubscription<SendMessageStartEvent> _sendMessageStartSubscription;
  late StreamSubscription<ClearMessagesEvent> _clearMessagesSubscription;

  final EventBus _eventBus = Imclient.IMEventBus;

  @override
  void initState() {
    super.initState();
    _connectionStatusSubscription = _eventBus.on<ConnectionStatusChangedEvent>().listen((event) {
      if(event.connectionStatus == kConnectionStatusConnected) {
        _loadConversation();
      }
    });

    _receiveMessageSubscription = _eventBus.on<ReceiveMessagesEvent>().listen((event) {
      if(!event.hasMore) {
        _loadConversation();
      }
    });
    _userSettingUpdatedSubscription = _eventBus.on<UserSettingUpdatedEvent>().listen((event) {
      _loadConversation();
    });
    _recallMessageSubscription = _eventBus.on<RecallMessageEvent>().listen((event) {
      _loadConversation();
    });
    _deleteMessageSubscription = _eventBus.on<DeleteMessageEvent>().listen((event) {
      _loadConversation();
    });
    _clearConversationUnreadSubscription = _eventBus.on<ClearConversationUnreadEvent>().listen((event) {
      _loadConversation();
    });
    _clearConversationsUnreadSubscription = _eventBus.on<ClearConversationsUnreadEvent>().listen((event) {
      _loadConversation();
    });
    _sendMessageStartSubscription = _eventBus.on<SendMessageStartEvent>().listen((event) {
      _loadConversation();
    });
    _clearMessagesSubscription = _eventBus.on<ClearMessagesEvent>().listen((event) {
      _loadConversation();
    });
    _loadConversation();
  }

  void _loadConversation() {
    debugPrint("load conversation");
    Imclient.getConversationInfos([ConversationType.Single, ConversationType.Group, ConversationType.Channel], [0]).then((value){
      int unreadCount = 0;
      for (var element in value) {
        if(!element.isSilent) {
          unreadCount += element.unreadCount.unread;
        }
      }
      widget.unreadCountCallback(unreadCount);
      setState(() {
        conversationInfoList = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: ListView.builder(
          itemCount: conversationInfoList.length,
          itemBuilder: /*1*/ (context, i) {
            ConversationInfo info = conversationInfoList[i];
            return _row(info, i);
          }),),
    );
  }

  Widget _row(ConversationInfo conversationInfo, int index) {
    return ConversationListItem(conversationInfo, index, longPressedCallback: _onLongPressed, conversationPressedCallback: (conversationInfo) {
      _toChatPage(conversationInfo.conversation);
    },);
  }

  void _toChatPage(Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MessagesScreen(conversation)),
    ).then((value) {
      _loadConversation();
    });
  }

  void _onLongPressed(ConversationInfo conversationInfo, int index, Offset position) {
    List<PopupMenuItem> items = [
      const PopupMenuItem(
        value: 'delete',
        child: Text('删除会话'),
      )
    ];

    if(conversationInfo.isTop > 0) {
      items.add(
          const PopupMenuItem(
            value: 'untop',
            child: Text('取消置顶'),
          )
      );
    } else {
      items.add(
          const PopupMenuItem(
            value: 'top',
            child: Text('置顶'),
          )
      );
    }

    if(conversationInfo.unreadCount.unread + conversationInfo.unreadCount.unreadMention + conversationInfo.unreadCount.unreadMentionAll > 0) {
      items.add(
          const PopupMenuItem(
            value: 'clear_unread',
            child: Text('清除未读'),
          )
      );
    } else {
      items.add(
          const PopupMenuItem(
            value: 'set_unread',
            child: Text('设为未读'),
          )
      );
    }

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: items,
    ).then((selected) {
      if (selected != null) {
        switch(selected) {
          case "delete":
            Imclient.removeConversation(conversationInfo.conversation, false).then((value) {
              setState(() {
                conversationInfoList.remove(conversationInfo);
              });
            });
            break;
          case "top":
            Imclient.setConversationTop(conversationInfo.conversation, 1, () {
              _loadConversation();
            }, (errorCode) {

            });
            break;
          case "untop":
            Imclient.setConversationTop(conversationInfo.conversation, 0, () {
              _loadConversation();
            }, (errorCode) {

            });
            break;
          case "clear_unread":
            Imclient.clearConversationUnreadStatus(conversationInfo.conversation).then((value) {
              _loadConversation();
            });
            break;
          case "set_unread":
            Imclient.markAsUnRead(conversationInfo.conversation, true).then((value) {
              _loadConversation();
            });
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    _connectionStatusSubscription.cancel();
    _receiveMessageSubscription.cancel();
    _userSettingUpdatedSubscription.cancel();
    _recallMessageSubscription.cancel();
    _deleteMessageSubscription.cancel();
    _clearConversationUnreadSubscription.cancel();
    _clearConversationsUnreadSubscription.cancel();
    _sendMessageStartSubscription.cancel();
    _clearMessagesSubscription.cancel();
    super.dispose();
  }
}


typedef OnLongPressedCallback = void Function(ConversationInfo conversationInfo, int index, Offset position);
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
    if(widget.conversationInfo.conversation.conversationType == ConversationType.Single) {
      userInfo = Cache.getUserInfo(widget.conversationInfo.conversation.target);
      Imclient.getUserInfo(widget.conversationInfo.conversation.target).then((value) {
        if(value != null && value != userInfo && value.userId == widget.conversationInfo.conversation.target) {
          Cache.putUserInfo(value);
          if(mounted) {
            setState(() {
              userInfo = value;
            });
          }
        }
      });
    } else if(widget.conversationInfo.conversation.conversationType == ConversationType.Group) {
      groupInfo = Cache.getGroupInfo(widget.conversationInfo.conversation.target);
      Imclient.getGroupInfo(widget.conversationInfo.conversation.target).then((value) {
        if(value != null && value != groupInfo && value.target == widget.conversationInfo.conversation.target) {
          Cache.putGroupInfo(value);
          if(mounted) {
            setState(() {
              groupInfo = value;
            });
          }
        }
      });
    } else if(widget.conversationInfo.conversation.conversationType == ConversationType.Channel) {
      Imclient.getChannelInfo(widget.conversationInfo.conversation.target).then((value) {
        channelInfo = Cache.getChannelInfo(widget.conversationInfo.conversation.target);
        if(value != null && value != channelInfo && value.channelId == widget.conversationInfo.conversation.target) {
          Cache.putChannelInfo(value);
          if(mounted) {
            setState(() {
              channelInfo = channelInfo;
            });
          }
        }
      });
    }

    if(widget.conversationInfo.lastMessage != null && widget.conversationInfo.lastMessage!.content != null) {
      digest = Cache.getConversationDigest(widget.conversationInfo.conversation);
      widget.conversationInfo.lastMessage!.content.digest(widget.conversationInfo.lastMessage!).then((value) {
        if(digest != value) {
          Cache.putConversationDigest(widget.conversationInfo.conversation, value);
          if(mounted) {
            setState(() {
              digest = value;
            });
          }
        }
      });
    }

    _draftUpdatedSubscription = _eventBus.on<ConversationDraftUpdatedEvent>().listen((event) {
      if(event.conversation == widget.conversationInfo.conversation) {
        setState(() {
          widget.conversationInfo.draft = event.draft;
        });
      }
    });
    _silentUpdatedSubscription = _eventBus.on<ConversationSilentUpdatedEvent>().listen((event) {
      if(event.conversation == widget.conversationInfo.conversation) {
        setState(() {
          widget.conversationInfo.isSilent = event.silent;
        });
      }
    });
    _topUpdatedSubscription = _eventBus.on<ConversationTopUpdatedEvent>().listen((event) {
      if(event.conversation == widget.conversationInfo.conversation) {
        setState(() {
          widget.conversationInfo.isTop = event.top;
        });
      }
    });
    if(widget.conversationInfo.lastMessage != null && widget.conversationInfo.lastMessage!.status == MessageStatus.Message_Status_Sending) {
      _sendMsgSuccessSubscription = _eventBus.on<SendMessageSuccessEvent>().listen((event) {
        if(event.messageId == widget.conversationInfo.lastMessage?.messageId) {
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

  void _updateWhenMsgSent(bool success) {

  }

  @override
  Widget build(BuildContext context) {
    String? portrait;
    String? localPortrait;
    String? convTitle;
    if(widget.conversationInfo.conversation.conversationType == ConversationType.Single) {
      if(userInfo != null && userInfo!.portrait != null && userInfo!.portrait!.isNotEmpty) {
        portrait = userInfo!.portrait!;
        convTitle = userInfo!.displayName!;
      } else {
        convTitle = '私聊';
      }
      localPortrait = Config.defaultUserPortrait;
    } else if(widget.conversationInfo.conversation.conversationType == ConversationType.Group) {
      if(groupInfo != null) {
        if(groupInfo!.portrait != null && groupInfo!.portrait!.isNotEmpty) {
          portrait = groupInfo!.portrait!;
        }
        if(groupInfo!.name != null && groupInfo!.name!.isNotEmpty) {
          convTitle = groupInfo!.name!;
        }
      } else {
        convTitle = '群聊';
      }
      localPortrait = Config.defaultGroupPortrait;
    } else if(widget.conversationInfo.conversation.conversationType == ConversationType.Channel) {
      if(channelInfo != null && channelInfo!.portrait != null && channelInfo!.portrait!.isNotEmpty) {
        portrait = channelInfo!.portrait!;
        convTitle = channelInfo!.name!;
      } else {
        convTitle = '频道';
      }
      localPortrait = Config.defaultChannelPortrait;
    }

    bool hasDraft = widget.conversationInfo.draft != null && widget.conversationInfo.draft!.isNotEmpty;

    return GestureDetector(
      child: Container(
        color: widget.conversationInfo.isTop > 0 ? CupertinoColors.secondarySystemBackground :  CupertinoColors.systemBackground,
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
                    )
                  ),
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
                              Row(children: [
                                _getMessageStatusIcon(),
                                hasDraft?const Text("[草稿]", style: TextStyle(fontSize: 12.0, color: Colors.red),):Container(),
                                Text(
                                  hasDraft?widget.conversationInfo.draft!:'$digest',
                                  style: const TextStyle(
                                      fontSize: 12.0,
                                      color: Color(0xffaaaaaa)),
                                  maxLines: 1,
                                  softWrap: true,
                                ),
                              ],),
                            ],
                          ))),
                  Column(children: [
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
                      child: widget.conversationInfo.isSilent ? Image.asset('assets/images/conversation_mute.png', width: 10, height: 10,) : null,
                    ),
                  ],),
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
      onLongPressStart: (details) => widget.longPressedCallback(widget.conversationInfo, widget.index, details.globalPosition),
    );
  }

  Widget _getMessageStatusIcon() {
    if(widget.conversationInfo.lastMessage != null) {
      if(widget.conversationInfo.lastMessage!.status == MessageStatus.Message_Status_Sending) {
        return Padding(padding: const EdgeInsets.fromLTRB(0, 0, 4, 0), child: Image.asset("assets/images/conversation_msg_sending.png", width: 16, height: 16,),);
      } else if(widget.conversationInfo.lastMessage!.status == MessageStatus.Message_Status_Send_Failure) {
        return Padding(padding: const EdgeInsets.fromLTRB(0, 0, 4, 0), child: Image.asset("assets/images/conversation_msg_failure.png", width: 16, height: 16,),);
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
