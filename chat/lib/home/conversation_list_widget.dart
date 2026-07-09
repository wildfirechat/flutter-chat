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
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/utilities.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/viewmodel/status_notification_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/settings/pc_online_devices_screen.dart';
import 'package:chat/l10n/app_localizations.dart';

import '../config.dart';
import '../conversation/conversation_screen.dart';
import '../viewmodel/user_view_model.dart';
import 'package:chat/theme/app_colors.dart';

/// 会话行的内容高度与分隔线高度。分隔线不随字号缩放,itemExtent 必须把它单独加上,
/// 否则 s < 1 时内容比 extent 高,debug 下会报 overflow。
const double _kConversationRowHeight = 64.0;
const double _kDividerHeight = 0.5;

double _conversationItemExtent(BuildContext context) =>
    LayoutScale.watchScale(context, _kConversationRowHeight, cap: LayoutScale.rowCap) + _kDividerHeight;

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
        // 桌面端中栏由 PCHome 铺 context.colors.middleBg,列表本身透明
        backgroundColor: isDesktopShell ? Colors.transparent : null,
        body: SafeArea(
          child: Column(
            children: [
              const StatusNotificationHeader(),
              Expanded(
                child: ListView.builder(
                    itemCount: conversationListViewModel.conversationList.length,
                    // 使用 ListView.builder 的 key 参数确保列表项在顺序变化时能正确更新
                    itemExtent: _conversationItemExtent(context),
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
          headers.add(_buildStatusBanner(context, AppLocalizations.of(context)!.connecting));
        } else if (viewModel.connectionStatus < 0) {
          headers.add(_buildStatusBanner(context, AppLocalizations.of(context)!.connectionFailed));
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
              color: context.colors.chatBg,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.computer, color: context.colors.textSecondary, size: 20),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.pcLoggedIn(pcStatus),
                      style: TextStyle(color: context.colors.textSecondary)),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: context.colors.textSecondary, size: 20),
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

  /// 连接中 / 连接失败横幅。淡红底 + 红字,明暗两套主题各取自己的 danger。
  Widget _buildStatusBanner(BuildContext context, String text) {
    final danger = context.colors.danger;
    return Container(
      height: 40,
      color: danger.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(text, style: TextStyle(color: danger)),
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

  /// 桌面端:透明底衬在中栏灰面上,hover/选中分别加深;置顶会话微微提亮。
  /// 移动端:列表铺在 surface 上,没有 hover,置顶同样提亮一档。
  ///
  /// 移动端原先用 CupertinoColors.systemBackground —— 那是 CupertinoDynamicColor,
  /// 不经 resolve 直接当 Color 用只会拿到浅色变体,暗色下会一直是白底。
  Color _cellBackground(bool hovered) {
    var conversationInfo = widget.conversationInfo;
    final colors = context.colors;
    if (isDesktopShell) {
      if (widget.isSelected) return colors.cellSelected;
      if (hovered) return colors.cellHover;
      return conversationInfo.isTop > 0 ? colors.cellTop : Colors.transparent;
    }
    if (widget.isSelected) return colors.cellSelected;
    return conversationInfo.isTop > 0 ? colors.cellTop : colors.surface;
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
                height: LayoutScale.watchScale(context, _kConversationRowHeight, cap: LayoutScale.rowCap),
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
                                    height: LayoutScale.watchScale(context, 48.0, cap: LayoutScale.rowCap),
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
                                                    style: TextStyle(fontSize: 12.0, color: context.colors.danger),
                                                  )
                                                : Container(),
                                            Expanded(
                                              child: Text(
                                                hasDraft
                                                    ? conversationInfo.draft!
                                                    : conversationInfo.lastMessage != null
                                                        ? '${value.$4?.getReadableName() ?? "<${conversationInfo.lastMessage!.fromUser}>"} : $lastMsgDigest'
                                                        : '',
                                                style: TextStyle(fontSize: 12.0, color: context.colors.textTertiary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )
                                          ],
                                        ),
                                      ],
                                    ))),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 15.0),
                                  child: Text(
                                    Utilities.formatTime(context, conversationInfo.timestamp),
                                    style: TextStyle(
                                      fontSize: 10.0,
                                      color: context.colors.textTertiary,
                                    ),
                                  ),
                                ),
                                if (conversationInfo.isSilent)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 15.0, top: 4.0),
                                    child: Image.asset(
                                      'assets/images/conversation_mute.png',
                                      width: 10,
                                      height: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        )),
              ),
              // 桌面端参照微信 PC 不加分隔线,由背景色区分;保留高度以维持 itemExtent
              Container(
                margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
                height: _kDividerHeight,
                color: isDesktopShell ? Colors.transparent : context.colors.hairlineSoft,
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
    final double itemHeight = isDesktopShell ? LayoutScale.scale(context, 34, cap: LayoutScale.rowCap) : kMinInteractiveDimension;
    List<PopupMenuItem> items = [
      PopupMenuItem(
        value: 'delete',
        height: itemHeight,
        child: Text(AppLocalizations.of(context)!.deleteConversation),
      )
    ];

    if (conversationInfo.isTop > 0) {
      items.add(PopupMenuItem(
        value: 'untop',
        height: itemHeight,
        child: Text(AppLocalizations.of(context)!.untop),
      ));
    } else {
      items.add(PopupMenuItem(
        value: 'top',
        height: itemHeight,
        child: Text(AppLocalizations.of(context)!.top),
      ));
    }

    if (conversationInfo.unreadCount.unread + conversationInfo.unreadCount.unreadMention + conversationInfo.unreadCount.unreadMentionAll > 0) {
      items.add(PopupMenuItem(
        value: 'clear_unread',
        height: itemHeight,
        child: Text(AppLocalizations.of(context)!.clearUnread),
      ));
    } else {
      items.add(PopupMenuItem(
        value: 'set_unread',
        height: itemHeight,
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
