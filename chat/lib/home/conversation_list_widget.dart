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
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/utilities.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/viewmodel/status_notification_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/settings/pc_online_devices_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../config.dart';
import '../conversation/conversation_screen.dart';
import '../viewmodel/user_view_model.dart';

class ConversationListWidget extends StatelessWidget {
  /// 桌面端 Shell 注入:点击会话时回调(替代默认的全屏 push),并高亮选中会话。
  /// 移动端不传,保持原有行为。
  final Function(Conversation conversation)? onConversationSelected;
  final Conversation? selectedConversation;

  const ConversationListWidget({super.key, this.onConversationSelected, this.selectedConversation});

  @override
  Widget build(BuildContext context) {
    var conversationListViewModel = Provider.of<ConversationListViewModel>(context);
    return ChangeNotifierProvider<StatusNotificationViewModel>(
      create: (_) => StatusNotificationViewModel(),
      child: Scaffold(
        // 桌面端中栏由 PCHome 铺 PcTheme.middleBg,列表本身透明
        backgroundColor: isDesktopShell ? Colors.transparent : null,
        body: SafeArea(
          child: Column(
            children: [
              const StatusNotificationHeader(),
              Expanded(
                child: ListView.builder(
                    itemCount: conversationListViewModel.conversationList.length,
                    // 使用 ListView.builder 的 key 参数确保列表项在顺序变化时能正确更新
                    itemExtent: 64.5,
                    key: ValueKey<int>(conversationListViewModel.conversationList.length),
                    cacheExtent: 200,
                    addRepaintBoundaries: true,
                    addAutomaticKeepAlives: false,
                    itemBuilder: (context, i) {
                      ConversationInfo info = conversationListViewModel.conversationList[i];
                      var key =
                          '${info.conversation.conversationType}-${info.conversation.target}-${info.conversation.conversationType}-${info.conversation.line}';
                      return ConversationListItem(
                        info,
                        key: ValueKey(key),
                        onTap: onConversationSelected,
                        isSelected: info.conversation == selectedConversation,
                      );
                    }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusNotificationHeader extends StatelessWidget {
  const StatusNotificationHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusNotificationViewModel>(
      builder: (context, viewModel, child) {
        List<Widget> headers = [];

        if (viewModel.connectionStatus == kConnectionStatusConnecting ||
            viewModel.connectionStatus == kConnectionStatusReceiving) {
          headers.add(Container(
            height: 40,
            color: Colors.red[100],
            alignment: Alignment.center,
            child: Text(AppLocalizations.of(context)!.connecting, style: const TextStyle(color: Colors.red)),
          ));
        } else if (viewModel.connectionStatus < 0) {
          headers.add(Container(
            height: 40,
            color: Colors.red[100],
            alignment: Alignment.center,
            child: Text(AppLocalizations.of(context)!.connectionFailed, style: const TextStyle(color: Colors.red)),
          ));
        }

        // “PC 已登录”横幅只对手机端有意义,桌面端自身就是 PC
        if (!isDesktopShell && viewModel.connectionStatus == kConnectionStatusConnected && viewModel.pcOnlineInfos.isNotEmpty) {
          String pcStatus = viewModel.pcOnlineInfos.map((e) {
            if (e.type == 0) return AppLocalizations.of(context)!.pcClient;
            if (e.type == 1) return AppLocalizations.of(context)!.webClient;
            if (e.type == 2) return AppLocalizations.of(context)!.miniProgram;
            return AppLocalizations.of(context)!.pcClient;
          }).toSet().join('/');
          headers.add(GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PCOnlineDevicesScreen())).then((_) {
                viewModel.refreshOnlineInfos();
              });
            },
            child: Container(
              height: 40,
              color: const Color(0xfff5f5f5),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.computer, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.pcLoggedIn(pcStatus), style: const TextStyle(color: Colors.grey)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ));
        }

        if (headers.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(children: headers);
      },
    );
  }
}

class ConversationListItem extends StatefulWidget {
  final ConversationInfo conversationInfo;
  final Function(Conversation conversation)? onTap;
  final bool isSelected;

  const ConversationListItem(this.conversationInfo, {super.key, this.onTap, this.isSelected = false});

  @override
  State<ConversationListItem> createState() => _ConversationListItemState();
}

class _ConversationListItemState extends State<ConversationListItem> with AutomaticKeepAliveClientMixin {
  String lastMsgDigest = '';
  bool isLoading = true;

  StreamSubscription<UserInfoUpdatedEvent>? _userInfoUpdatedSubscription;

  @override
  bool get wantKeepAlive => true;

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

  @override
  void didUpdateWidget(ConversationListItem oldWidget){
    super.didUpdateWidget(oldWidget);
    // 只要会话信息对象改变了，就重新加载 digest
    if (oldWidget.conversationInfo != widget.conversationInfo) {
      _loadLastMessageDigest();
    }
  }

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

    if (isDesktopShell) {
      return RepaintBoundary(
        child: HoverBuilder(
          cursor: SystemMouseCursors.click,
          builder: (context, hovered) => _buildCell(context, hovered),
        ),
      );
    }
    return RepaintBoundary(child: _buildCell(context, false));
  }

  /// 桌面端:透明底衬在中栏暖灰上,hover/选中分别加深;置顶会话微微提亮。
  /// 移动端:维持原 Cupertino 配色。
  Color _cellBackground(bool hovered) {
    var conversationInfo = widget.conversationInfo;
    if (isDesktopShell) {
      if (widget.isSelected) return PcTheme.cellSelected;
      if (hovered) return PcTheme.cellHover;
      return conversationInfo.isTop > 0 ? const Color(0xFFEFEEED) : Colors.transparent;
    }
    return widget.isSelected
        ? const Color(0xffd6d6d6)
        : conversationInfo.isTop > 0
            ? CupertinoColors.secondarySystemBackground
            : CupertinoColors.systemBackground;
  }

  Widget _buildCell(BuildContext context, bool hovered) {
    var conversationInfo = widget.conversationInfo;
    bool hasDraft = conversationInfo.draft != null && conversationInfo.draft!.isNotEmpty;

    return GestureDetector(
      child: Container(
          color: _cellBackground(hovered),
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
                                          Utilities.conversationTitle(context, conversationInfo.conversation, value.$1, value.$2, value.$3),
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
                                                ? Text(
                                                    AppLocalizations.of(context)!.draftTag,
                                                    style: const TextStyle(fontSize: 12.0, color: Colors.red),
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
                                    Utilities.formatTime(context, conversationInfo.timestamp),
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
              // 桌面端参照微信 PC 不加分隔线,由背景色区分;保留高度以维持 itemExtent
              Container(
                margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
                height: 0.5,
                color: isDesktopShell ? Colors.transparent : const Color(0xffebebeb),
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
      // 桌面端右键弹出同一套会话操作菜单(置顶/删除/未读)
      onSecondaryTapUp: (details) => _onLongPressed(context, conversationInfo, details.globalPosition),
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
      PopupMenuItem(
        value: 'delete',
        child: Text(AppLocalizations.of(context)!.deleteConversation),
      )
    ];

    if (conversationInfo.isTop > 0) {
      items.add(PopupMenuItem(
        value: 'untop',
        child: Text(AppLocalizations.of(context)!.untop),
      ));
    } else {
      items.add(PopupMenuItem(
        value: 'top',
        child: Text(AppLocalizations.of(context)!.top),
      ));
    }

    if (conversationInfo.unreadCount.unread + conversationInfo.unreadCount.unreadMention + conversationInfo.unreadCount.unreadMentionAll > 0) {
      items.add(PopupMenuItem(
        value: 'clear_unread',
        child: Text(AppLocalizations.of(context)!.clearUnread),
      ));
    } else {
      items.add(PopupMenuItem(
        value: 'set_unread',
        child: Text(AppLocalizations.of(context)!.setUnread),
      ));
    }

    var conversationListViewModel = Provider.of<ConversationListViewModel>(context, listen: false);
    showMenu(
      context: context,
      // 桌面端菜单直接从鼠标位置展开;移动端保留左偏,避免长按时菜单出屏
      position: isDesktopShell
          ? RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy)
          : RelativeRect.fromLTRB(position.dx - 120, position.dy, position.dx, position.dy),
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
