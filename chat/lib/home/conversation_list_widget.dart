import 'dart:async';

import '../widgets/unread_badge.dart';
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
import 'package:chat/mesh/mesh_cache.dart';
import 'package:chat/utils/mesh_user_display.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/viewmodel/status_notification_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/settings/pc_online_devices_screen.dart';
import 'package:chat/l10n/app_localizations.dart';

import '../config.dart';
import '../conversation/conversation_screen.dart';
import '../conversation/input_bar/draft_data.dart';
import '../viewmodel/user_view_model.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/widget/desktop_popup_menu_item.dart';
import 'package:chat/widget/middle_ellipsis_text.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/external_target_utils.dart';

/// 会话行的内容高度与分隔线高度。分隔线不随字号缩放,itemExtent 必须把它单独加上,
/// 否则 s < 1 时内容比 extent 高,debug 下会报 overflow。
const double _kConversationRowHeightMobile = 64.0;
const double _kConversationRowHeightDesktop = 70.0;
double get kConversationRowHeight => isDesktopShell ? _kConversationRowHeightDesktop : _kConversationRowHeightMobile;
const double _kDividerHeight = 0.5;

double conversationItemExtent(BuildContext context) =>
    LayoutScale.watchScale(context, kConversationRowHeight, cap: LayoutScale.rowCap) + _kDividerHeight;

class ConversationListWidget extends StatelessWidget {
  /// 桌面端 Shell 注入:点击会话时回调(替代默认的全屏 push),并高亮选中会话。
  /// 移动端不传,保持原有行为。
  final Function(Conversation conversation)? onConversationSelected;
  final Conversation? selectedConversation;
  final ScrollController? scrollController;
  final ValueNotifier<double>? scrollOffset;

  const ConversationListWidget({
    super.key,
    this.onConversationSelected,
    this.selectedConversation,
    this.scrollController,
    this.scrollOffset,
  });

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
                child: isDesktopShell && scrollOffset != null
                    ? ValueListenableBuilder<double>(
                        valueListenable: scrollOffset!,
                        builder: (context, offset, child) {
                          final list = conversationListViewModel.conversationList;
                          final isFirstItemPinned = list.isNotEmpty && list[0].isTop > 0;
                          final overscrollHeight = (offset < 0 && isFirstItemPinned) ? -offset : 0.0;
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  color: context.colors.middleBgDesktop,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: overscrollHeight,
                                child: Container(
                                  color: context.colors.cellTopDesktop,
                                ),
                              ),
                              Positioned.fill(
                                child: child!,
                              ),
                            ],
                          );
                        },
                child: ListView.builder(
                          controller: scrollController,
                          itemCount: conversationListViewModel.conversationList.length,
                          itemExtent: conversationItemExtent(context),
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
                          },
                        ),
                      )
                    : ListView.builder(
                    itemCount: conversationListViewModel.conversationList.length,
                        itemExtent: conversationItemExtent(context),
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
                        },
                      ),
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
  /// 如果提供，则替换默认右侧的时间/静音区域，用于选择会话等场景。
  final Widget? trailing;
  /// 是否显示最后一条消息摘要等副标题内容。
  final bool showSubtitle;
  /// 是否启用长按/右键菜单。
  final bool enableLongPress;

  const ConversationListItem(this.conversationInfo, {super.key, this.onTap, this.isSelected = false, this.trailing, this.showSubtitle = true, this.enableLongPress = true});

  @override
  State<ConversationListItem> createState() => _ConversationListItemState();
}

class _ConversationListItemState extends State<ConversationListItem> with AutomaticKeepAliveClientMixin {
  String lastMsgDigest = '';
  bool isLoading = true;
  int _joinRequestCount = 0;

  StreamSubscription<UserInfoUpdatedEvent>? _userInfoUpdatedSubscription;
  StreamSubscription<JoinGroupRequestUpdatedEvent>? _joinGroupRequestSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.showSubtitle) {
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
      _loadJoinRequestCount();
      _joinGroupRequestSubscription = Imclient.IMEventBus.on<JoinGroupRequestUpdatedEvent>().listen((_) {
        _loadJoinRequestCount();
      });
    } else {
      isLoading = false;
    }
  }

  @override
  void dispose() {
    super.dispose();
    _userInfoUpdatedSubscription?.cancel();
    _joinGroupRequestSubscription?.cancel();
  }

  @override
  void didUpdateWidget(ConversationListItem oldWidget){
    super.didUpdateWidget(oldWidget);
    // 只要会话信息对象改变了，就重新加载 digest
    if (oldWidget.conversationInfo != widget.conversationInfo) {
      if (widget.showSubtitle) {
        _loadLastMessageDigest();
        _loadJoinRequestCount();
      }
    }
    // 副标题由隐藏切为显示时，需要补加载数据
    if (!oldWidget.showSubtitle && widget.showSubtitle) {
      _loadLastMessageDigest();
      _loadJoinRequestCount();
    }
  }

  Future<void> _loadJoinRequestCount() async {
    if (widget.conversationInfo.conversation.conversationType != ConversationType.Group) {
      if (_joinRequestCount != 0) {
        setState(() => _joinRequestCount = 0);
      }
      return;
    }
    try {
      final count = await Imclient.getJoinGroupRequestUnread(
          groupId: widget.conversationInfo.conversation.target);
      if (mounted && count != _joinRequestCount) {
        setState(() => _joinRequestCount = count);
      }
    } catch (e) {
      // ignore
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

  /// 桌面端:透明底衬在中栏灰面上,选中走品牌色,置顶会话微微加深。
  /// hover 是半透明蒙层,叠在该行的静止底色上 —— 置顶行自带一层加深,
  /// 直接换成实色会跟它的静止态撞色,hover 就没了。
  /// 移动端:列表铺在 surface 上,没有 hover,置顶同样加深一档。
  ///
  /// 移动端原先用 CupertinoColors.systemBackground —— 那是 CupertinoDynamicColor,
  /// 不经 resolve 直接当 Color 用只会拿到浅色变体,暗色下会一直是白底。
  Color _cellBackground(bool hovered) {
    var conversationInfo = widget.conversationInfo;
    final colors = context.colors;
    if (isDesktopShell) {
      if (widget.isSelected) return colors.cellSelectedDesktop;
      final isTop = conversationInfo.isTop > 0;
      if (!hovered) return isTop ? colors.cellTopDesktop : Colors.transparent;
      // 蒙层要叠在实底上才有效:普通行的实底是 PCHome/本列表铺的中栏灰面
      return Color.alphaBlend(colors.cellHoverDesktop, isTop ? colors.cellTopDesktop : colors.middleBgDesktop);
    }
    if (widget.isSelected) return colors.cellSelected;
    return conversationInfo.isTop > 0 ? colors.cellTop : colors.surface;
  }

  Widget _buildCell(BuildContext context, bool hovered) {
    var conversationInfo = widget.conversationInfo;
    bool hasDraft = conversationInfo.draft != null && conversationInfo.draft!.isNotEmpty;

    void onTap() {
      if (widget.onTap != null) {
        widget.onTap!(conversationInfo.conversation);
      } else {
        _toChatPage(context, conversationInfo.conversation);
      }
    }

    final cellChild = Column(
      children: <Widget>[
        Container(
          height: LayoutScale.watchScale(context, kConversationRowHeight, cap: LayoutScale.rowCap),
          margin: EdgeInsets.only(left: isDesktopShell ? 11 : 15),
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
                    conversationInfo.lastMessage != null && widget.showSubtitle
                        ? userViewModel.getUserInfo(conversationInfo.lastMessage!.fromUser,
                            groupId: conversationInfo.conversation.conversationType == ConversationType.Group ? conversationInfo.conversation.target : null)
                        : null
                  ),
              builder: (context, value, child) => Row(
                    children: <Widget>[
                      UnreadBadge(
                        count: conversationInfo.unreadCount.unread,
                        asDot: conversationInfo.isSilent,
                        child: _buildPortraitImage(conversationInfo.conversation, value.$1, value.$2, value.$3),
                      ),
                      Expanded(
                          child: Container(
                              height: LayoutScale.watchScale(context, 48.0, cap: LayoutScale.rowCap),
                              alignment: Alignment.centerLeft,
                              margin: EdgeInsets.only(left: isDesktopShell ? 11 : 15),
                              child: widget.showSubtitle
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        _buildConversationTitle(value.$1, value.$2, value.$3),
                                        Container(
                                          height: 2,
                                        ),
                                        Row(
                                          children: [
                                            _messageStatusIcon(),
                                            hasDraft
                                                ? Text(
                                                    AppLocalizations.of(context)!.draftTag,
                                                    style: AppText.xs.copyWith(color: context.colors.danger),
                                                  )
                                                : Container(),
                                            if (_joinRequestCount > 0) ...[
                                              Text(
                                                '[${AppLocalizations.of(context)!.newJoinGroupRequestCount(_joinRequestCount)}]',
                                                style: AppText.xs.copyWith(color: Colors.red),
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Expanded(
                                              // Selector 复用同一 UserInfo 实例不会因域名到达而重估，这里单独监听 MeshCache
                                              child: AnimatedBuilder(
                                                animation: MeshCache.instance,
                                                builder: (context, child) => _buildLastMessagePreview(
                                                  context,
                                                  hasDraft,
                                                  conversationInfo,
                                                  value.$4,
                                                  lastMsgDigest,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : _buildConversationTitle(value.$1, value.$2, value.$3))),
                      widget.trailing ??
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 15.0),
                                child: Text(
                                  Utilities.formatTime(context, conversationInfo.timestamp),
                                  style: AppText.xxs.copyWith(color: (isDesktopShell && widget.isSelected) ? Colors.white : context.colors.textTertiary),
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
          margin: EdgeInsets.fromLTRB(
            isDesktopShell
                ? 12.0
                : 15.0 + LayoutScale.watchScale(context, 48.0, cap: LayoutScale.iconCap) + 15.0,
            0.0,
            12.0,
            0.0,
          ),
          height: _kDividerHeight,
          color: isDesktopShell ? context.colors.cellTopDesktop : context.colors.hairlineSoft,
        ),
      ],
    );

    if (isDesktopShell) {
      return Material(
        color: _cellBackground(hovered),
        child: GestureDetector(
          onTap: onTap,
          onLongPressStart: widget.enableLongPress ? (details) => _onLongPressed(context, conversationInfo, details.globalPosition) : null,
          onSecondaryTapUp: widget.enableLongPress ? (details) => _onLongPressed(context, conversationInfo, details.globalPosition) : null,
          behavior: HitTestBehavior.opaque,
          child: cellChild,
        ),
      );
    }

    return Material(
      color: _cellBackground(hovered),
      child: InkWell(
        onTap: onTap,
        child: GestureDetector(
          onLongPressStart: widget.enableLongPress ? (details) => _onLongPressed(context, conversationInfo, details.globalPosition) : null,
          onSecondaryTapUp: widget.enableLongPress ? (details) => _onLongPressed(context, conversationInfo, details.globalPosition) : null,
          behavior: HitTestBehavior.opaque,
          child: cellChild,
        ),
      ),
    );
  }

  /// 会话标题：外部域用户显示带黄色、小字号域后缀的富文本。
  Widget _buildConversationTitle(UserInfo? targetUserInfo, GroupInfo? targetGroupInfo, ChannelInfo? targetChannelInfo) {
    final conversation = widget.conversationInfo.conversation;
    final titleStyle = AppText.lg.copyWith(
      color: (isDesktopShell && widget.isSelected) ? Colors.white : null,
    );
    if (conversation.conversationType == ConversationType.Single &&
        targetUserInfo != null &&
        ExternalTargetUtils.isExternalTarget(targetUserInfo.userId)) {
      return Text.rich(
        MeshUserDisplay.getReadableNameSpan(targetUserInfo, style: titleStyle),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return MiddleEllipsisText(
      Utilities.conversationTitle(context, conversation, targetUserInfo, targetGroupInfo, targetChannelInfo),
      style: titleStyle,
    );
  }

  /// 最后一条消息摘要：外部域发送者名称使用带黄色、小字号域后缀的富文本。
  Widget _buildLastMessagePreview(
    BuildContext context,
    bool hasDraft,
    ConversationInfo conversationInfo,
    UserInfo? lastMessageSender,
    String lastMsgDigest,
  ) {
    final textStyle = AppText.xs.copyWith(
      color: (isDesktopShell && widget.isSelected) ? Colors.white : context.colors.textTertiary,
    );
    if (hasDraft) {
      return Text(
        DraftData.displayText(conversationInfo.draft!),
        style: textStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (conversationInfo.lastMessage == null) {
      return Text('', style: textStyle);
    }
    final senderName = lastMessageSender != null
        ? MeshUserDisplay.getReadableNameSpan(lastMessageSender, style: textStyle)
        : TextSpan(text: '<${conversationInfo.lastMessage!.fromUser}>', style: textStyle);
    return Text.rich(
      TextSpan(
        children: [
          senderName,
          TextSpan(text: ' : $lastMsgDigest', style: textStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
    return isDesktopShell
        ? Portrait(portrait, defaultPortrait, width: 44.0, height: 44.0, borderRadius: 6.0)
        : Portrait(portrait, defaultPortrait, borderRadius: 6.0);
  }


  void _toChatPage(BuildContext context, Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ConversationScreen(conversation)),
    ).then((value) {});
  }

  void _onLongPressed(BuildContext context, ConversationInfo conversationInfo, Offset position) {
    final double itemHeight = isDesktopShell ? LayoutScale.scale(context, 34, cap: LayoutScale.rowCap) : kMinInteractiveDimension;
    final List<Map<String, dynamic>> menuDefs = [];

    if (conversationInfo.isTop > 0) {
      menuDefs.add({
        'value': 'untop',
        'label': AppLocalizations.of(context)!.untop,
      });
    } else {
      menuDefs.add({
        'value': 'top',
        'label': AppLocalizations.of(context)!.top,
      });
    }

    if (conversationInfo.unreadCount.unread + conversationInfo.unreadCount.unreadMention + conversationInfo.unreadCount.unreadMentionAll > 0) {
      menuDefs.add({
        'value': 'clear_unread',
        'label': AppLocalizations.of(context)!.clearUnread,
      });
    } else {
      menuDefs.add({
        'value': 'set_unread',
        'label': AppLocalizations.of(context)!.setUnread,
      });
    }

    // WeChat style: delete is dangerous and placed at the very end
    menuDefs.add({
      'value': 'delete',
      'label': AppLocalizations.of(context)!.deleteConversation,
      'isDanger': true,
    });

    final List<PopupMenuEntry<String>> items = menuDefs.map((def) {
      if (isDesktopShell) {
        return DesktopPopupMenuItem<String>(
          value: def['value'] as String,
          isDanger: def['isDanger'] == true,
          height: itemHeight,
          child: Text(def['label'] as String),
        );
      } else {
        return PopupMenuItem<String>(
          value: def['value'] as String,
          height: itemHeight,
          child: Text(def['label'] as String),
        );
      }
    }).toList();

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
