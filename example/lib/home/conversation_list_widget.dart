import 'dart:async';

import 'package:badges/badges.dart' as badge;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/utilities.dart';
import 'package:wfc_example/viewmodel/channel_view_model.dart';
import 'package:wfc_example/viewmodel/conversation_list_view_model.dart';
import 'package:wfc_example/viewmodel/group_view_model.dart';
import 'package:wfc_example/viewmodel/user_view_model.dart';
import 'package:wfc_example/widget/portrait.dart';

import '../config.dart';
import '../conversation/conversation_screen.dart';

class ConversationListWidget extends StatelessWidget {
  const ConversationListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var conversationListViewModel = Provider.of<ConversationListViewModel>(context);
    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
            itemCount: conversationListViewModel.conversationList.length,
            // 使用 ListView.builder 的 key 参数确保列表项在顺序变化时能正确更新
            itemExtent: 64.5,
            key: ValueKey<int>(conversationListViewModel.conversationList.length),
            itemBuilder: (context, i) {
              ConversationInfo info = conversationListViewModel.conversationList[i];
              var key =
                  '${info.conversation.conversationType}-${info.conversation.target}-${info.conversation.conversationType}-${info.conversation.line}-${info.timestamp}';
              return ConversationListItem(
                info,
                key: ValueKey(key),
              );
            }),
      ),
    );
  }
}

class ConversationListItem extends StatefulWidget {
  final ConversationInfo conversationInfo;
  final Function(Conversation conversation)? onTap;

  const ConversationListItem(this.conversationInfo, {super.key, this.onTap});

  @override
  State<ConversationListItem> createState() => _ConversationListItemState();
}

class _ConversationListItemState extends State<ConversationListItem> with AutomaticKeepAliveClientMixin {
  String lastMsgDigest = '';
  bool isLoading = true;

  StreamSubscription<UserInfoUpdatedEvent>? _userInfoUpdatedSubscription;

  @override
  bool get wantKeepAlive => true; // 保持状态，防止滚动时重建

  @override
  void initState() {
    super.initState();
    var lastMessage = widget.conversationInfo.lastMessage;
    // FIXME
    // optimization
    // TODO 更细致的判断，仅包含用户信息的消息，比如加群等消息，需要重新加载 lastMessage
    if (lastMessage != null && lastMessage.content is NotificationMessageContent) {
      _userInfoUpdatedSubscription = Imclient.IMEventBus.on<UserInfoUpdatedEvent>().listen((event) {
        _loadLastMessageDigest();
      });
    }
    _loadLastMessageDigest();
  }

  @override
  void dispose() {
    super.dispose();
    _userInfoUpdatedSubscription?.cancel();
  }

  // @override
  // void didUpdateWidget(ConversationListItem oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  //   // 如果会话更新了，重新加载数据
  //   if (oldWidget.conversationInfo.conversationInfo.timestamp != widget.conversationInfo.conversationInfo.timestamp) {
  //     _loadData();
  //   }
  // }

  // 未使用 futureBuilder
  Future<void> _loadLastMessageDigest() async {
    try {
      var digest = '';
      if (widget.conversationInfo.lastMessage != null) {
        digest = await widget.conversationInfo.lastMessage!.content.digest(widget.conversationInfo.lastMessage!);
      }
      if (mounted) {
        setState(() {
          lastMsgDigest = digest;
          isLoading = false;
        });
      }
    } catch (error) {
      debugPrint("Error fetching conversation data: $error");
      if (mounted) {
        setState(() {
          // 设置默认值以避免UI错误
          lastMsgDigest = "";
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    var conversationInfo = widget.conversationInfo;
    bool hasDraft = conversationInfo.draft != null && conversationInfo.draft!.isNotEmpty;

    // 如果数据正在加载中，显示占位UI
    // if (isLoading) {
    //   return _buildPlaceholder(conversationInfo);
    // }

    return GestureDetector(
      child: Container(
          color: conversationInfo.isTop > 0 ? CupertinoColors.secondarySystemBackground : CupertinoColors.systemBackground,
          child: Column(
            children: <Widget>[
              Container(
                height: 64.0,
                margin: const EdgeInsets.only(left: 15),
                child: Selector3<UserViewModel, GroupViewModel, ChannelViewModel,
                        (UserInfo? targetUserInfo, GroupInfo? targetGroupInfo, ChannelInfo? channelInfo, UserInfo? lastMessageSenderUserInfo)>(
                    selector: (context, userViewModel, groupViewModel, channelViewModel) => (
                          conversationInfo.conversation.conversationType == ConversationType.Single
                              ? userViewModel.getUserInfo(conversationInfo.conversation.target)
                              : null,
                          conversationInfo.conversation.conversationType == ConversationType.Group
                              ? groupViewModel.getGroupInfo(conversationInfo.conversation.target)
                              : null,
                          conversationInfo.conversation.conversationType == ConversationType.Channel
                              ? channelViewModel.getChannelInfo(conversationInfo.conversation.target)
                              : null,
                          conversationInfo.lastMessage != null
                              ? userViewModel.getUserInfo(conversationInfo.lastMessage!.fromUser,
                                  groupId: conversationInfo.conversation.conversationType == ConversationType.Group ? conversationInfo.conversation.target : null)
                              : null
                        ),
                    builder: (context, value, child) => Row(
                          children: <Widget>[
                            badge.Badge(
                              showBadge: conversationInfo.unreadCount.unread > 0,
                              badgeContent: Text(conversationInfo.isSilent ? '' : '${conversationInfo.unreadCount.unread}'),
                              child: _buildPortraitImage(conversationInfo.conversation, value.$1, value.$2, value.$3),
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
                                          Utilities.conversationTitle(conversationInfo.conversation, value.$1, value.$2, value.$3),
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
                                                hasDraft
                                                    ? conversationInfo.draft!
                                                    : conversationInfo.lastMessage != null
                                                        ? '${value.$4?.getReadableName() ?? "<${conversationInfo.lastMessage!.fromUser}>"} : $lastMsgDigest'
                                                        : '',
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
                        )),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
                height: 0.5,
                color: const Color(0xffebebeb),
              ),
            ],
          )),
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!(conversationInfo.conversation);
        } else {
          _toChatPage(context, conversationInfo.conversation);
        }
      },
      onLongPressStart: (details) => _onLongPressed(context, conversationInfo, details.globalPosition),
    );
  }

  Widget _buildPortraitImage(Conversation conversation, UserInfo? userInfo, GroupInfo? groupInfo, ChannelInfo? channelInfo) {
    String portrait = switch (conversation.conversationType) {
      ConversationType.Single => userInfo?.portrait ?? Config.defaultUserPortrait,
      ConversationType.Group => groupInfo?.portrait ?? Config.defaultGroupPortrait,
      ConversationType.Channel => channelInfo?.portrait ?? Config.defaultChannelPortrait,
      _ => ''
    };
    var defaultPortrait = widget.conversationInfo.conversation.conversationType == ConversationType.Single
        ? Config.defaultUserPortrait
        : widget.conversationInfo.conversation.conversationType == ConversationType.Group
            ? Config.defaultGroupPortrait
            : Config.defaultChannelPortrait;
    return Portrait(portrait, defaultPortrait, borderRadius: 6.0);
  }


  void _toChatPage(BuildContext context, Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ConversationScreen(conversation)),
    ).then((value) {});
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
    var conversationInfo = widget.conversationInfo;
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
