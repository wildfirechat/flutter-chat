import 'dart:io';

import 'package:badges/badges.dart' as badge;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/contact/search_user.dart';
import 'package:chat/home/conversation_list_widget.dart';
import 'package:chat/pc/pc_contact_list.dart';
import 'package:chat/pc/pc_conversation_pane.dart';
import 'package:chat/pc/pc_discovery_list.dart';
import 'package:chat/pc/pc_search_view.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/settings/me_tab.dart';
import 'package:chat/user_info_widget.dart';
import 'package:chat/viewmodel/contact_list_view_model.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/workspace/work_space.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 桌面端三栏 Shell:侧栏(tab 切换)+ 中栏(搜索 + 各 tab 列表)+ 右栏(嵌套 Navigator 的详情区)。
/// 会话/联系人/搜索结果点击通过回调注入,在右栏内打开;二级页面(群信息等)在右栏内部导航。
/// 视觉体系见 [PcTheme]。
class PCHome extends StatefulWidget {
  const PCHome({super.key});

  @override
  State<PCHome> createState() => _PCHomeState();
}

class _PCHomeState extends State<PCHome> {
  final GlobalKey<NavigatorState> _paneNavKey = GlobalKey<NavigatorState>();
  final PCShellViewModel _shellViewModel = PCShellViewModel();

  late ConversationListViewModel _conversationListViewModel;

  /// 右栏当前是否展示着会话页。用于:
  /// - 从其它 tab 切回消息 tab 时恢复上次会话;
  /// - 避免对同一会话重复 push(新旧页 initState/dispose 交叠会清掉 viewModel)。
  bool _paneShowsConversation = false;

  /// 选中会话是否已在会话列表中出现过。新建会话在发出首条消息前不在列表里,
  /// 用它区分“尚未入列”与“被删除”,只在后者时清空右栏。
  bool _selectedSeenInList = false;

  @override
  void initState() {
    super.initState();
    _shellViewModel.conversationOpener = _openConversation;
    _shellViewModel.pageOpener = _openPage;
    _conversationListViewModel = Provider.of<ConversationListViewModel>(context, listen: false);
    _conversationListViewModel.addListener(_onConversationListChanged);
  }

  @override
  void dispose() {
    _conversationListViewModel.removeListener(_onConversationListChanged);
    _shellViewModel.dispose();
    super.dispose();
  }

  /// 选中的会话被删除(在列表中出现过、现在消失了)时,清空右栏。
  void _onConversationListChanged() {
    final selected = _shellViewModel.selectedConversation;
    if (selected == null || selected.conversationType == ConversationType.Chatroom) {
      return;
    }
    final exists = _conversationListViewModel.conversationList.any((info) => info.conversation == selected);
    if (exists) {
      _selectedSeenInList = true;
    } else if (_selectedSeenInList) {
      _selectedSeenInList = false;
      _shellViewModel.selectConversation(null);
      _clearRightPane();
    }
  }

  void _clearRightPane() {
    _paneShowsConversation = false;
    _paneNavKey.currentState?.popUntil((route) => route.isFirst);
  }

  /// 右栏内的路由不做转场动画,桌面端切换详情应即时呈现。
  Route<dynamic> _paneRoute(Widget page, [RouteSettings? settings]) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  void _openConversation(Conversation conversation, {int? toFocusMessageId}) {
    if (_shellViewModel.selectedConversation == conversation && toFocusMessageId == null && _paneShowsConversation) {
      return;
    }
    _shellViewModel.selectTab(PCShellViewModel.tabChat);
    _shellViewModel.selectConversation(conversation);
    _selectedSeenInList = false;
    _pushConversationPane(conversation, toFocusMessageId: toFocusMessageId);
  }

  void _pushConversationPane(Conversation conversation, {int? toFocusMessageId}) {
    _paneShowsConversation = true;
    _paneNavKey.currentState!.pushAndRemoveUntil(
      _paneRoute(PcConversationPane(
        conversation,
        toFocusMessageId: toFocusMessageId,
        key: ValueKey('pc-conv-${conversation.conversationType.index}-${conversation.target}-${conversation.line}-${toFocusMessageId ?? 0}'),
      )),
      (route) => route.isFirst,
    );
  }

  void _openUser(String userId) {
    _openPage(UserInfoWidget(userId, key: ValueKey('pc-user-$userId')));
  }

  /// 在右栏打开任意页面(用户详情/好友请求/组织架构/网页等)。
  /// 不清除会话选中态:切回消息 tab 时按选中态恢复会话。
  void _openPage(Widget page) {
    _paneShowsConversation = false;
    _paneNavKey.currentState!.pushAndRemoveUntil(
      _paneRoute(page),
      (route) => route.isFirst,
    );
  }

  /// 右栏内容跟随侧栏 tab:消息 tab 恢复上次选中的会话,
  /// 工作台整栏展示网页,其余 tab 回到空态等待本栏选择。
  void _onTabSelected(int tab) {
    final int previous = _shellViewModel.selectedTab;
    _shellViewModel.selectTab(tab);
    if (tab == PCShellViewModel.tabWork) {
      _openPage(const WorkSpace());
      return;
    }
    if (tab == previous) {
      return;
    }
    if (tab == PCShellViewModel.tabChat) {
      final selected = _shellViewModel.selectedConversation;
      if (selected != null) {
        if (!_paneShowsConversation) {
          _pushConversationPane(selected);
        }
      } else {
        _clearRightPane();
      }
    } else {
      _clearRightPane();
    }
  }

  /// 搜索以浮层形态覆盖在中栏之上(微信 PC 形态),Esc/点击外部关闭。
  void _openSearchModal() {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.12),
        transitionDuration: const Duration(milliseconds: 120),
        reverseTransitionDuration: const Duration(milliseconds: 100),
        pageBuilder: (routeContext, animation, _) => Stack(
          children: [
            Positioned(
              left: PcTheme.sideBarWidth,
              top: 0,
              bottom: 0,
              width: PcTheme.middleColumnWidth,
              child: FadeTransition(
                opacity: animation,
                child: Material(
                  color: PcTheme.middleBg,
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.3),
                  child: PcSearchView(
                    onClose: () => Navigator.of(routeContext).pop(),
                    onUserSelected: (userId) {
                      Navigator.of(routeContext).pop();
                      _openUser(userId);
                    },
                    onConversationSelected: (conversation, {focusMessageId}) {
                      Navigator.of(routeContext).pop();
                      _openConversation(conversation, toFocusMessageId: focusMessageId);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startChat() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 420,
          height: 560,
          child: PickUserScreen(title: AppLocalizations.of(context)!.startChat, (pickerContext, members) async {
            if (members.isEmpty) {
              Fluttertoast.showToast(msg: "请选择一位或者多位好友发起聊天");
            } else if (members.length == 1) {
              Navigator.pop(pickerContext);
              _openConversation(Conversation(conversationType: ConversationType.Single, target: members[0]));
            } else {
              _showProcessingDialog(pickerContext, "群组创建中...");

              List<UserInfo> userInfos = await Imclient.getUserInfos(members);
              UserInfo? creator = await Imclient.getUserInfo(Imclient.currentUserId);
              String groupName = creator!.displayName!;
              for (var user in userInfos) {
                if (user.displayName != null) {
                  if ('$groupName,${user.displayName}'.length > 24) {
                    groupName = '$groupName等';
                    break;
                  } else {
                    groupName = '$groupName,${user.displayName}';
                  }
                }
              }

              Imclient.createGroup(null, groupName, null, GroupType.Restricted.index, members, (strValue) {
                Navigator.pop(pickerContext); // 关闭进度对话框
                Navigator.pop(pickerContext); // 关闭选人对话框
                _openConversation(Conversation(conversationType: ConversationType.Group, target: strValue));
              }, (errorCode) {
                Navigator.pop(pickerContext);
                Fluttertoast.showToast(msg: '创建失败：$errorCode');
              });
            }
          }),
        ),
      ),
    );
  }

  void _showProcessingDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(title),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PcTheme.themeData(context),
      child: ChangeNotifierProvider<PCShellViewModel>.value(
        value: _shellViewModel,
        child: Scaffold(
          body: Row(
            children: [
              SizedBox(width: PcTheme.sideBarWidth, child: _PcSideBar(onTabSelected: _onTabSelected)),
              SizedBox(width: PcTheme.middleColumnWidth, child: _buildMiddleColumn(context)),
              Container(width: 0.5, color: PcTheme.hairline),
              Expanded(
                child: ClipRect(
                  child: Navigator(
                    key: _paneNavKey,
                    onGenerateRoute: (settings) => _paneRoute(const _EmptyDetailPane(), settings),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiddleColumn(BuildContext context) {
    return Container(
      color: PcTheme.middleBg,
      child: Consumer<PCShellViewModel>(
        builder: (context, shell, _) {
          return Column(
            children: [
              _MiddleColumnHeader(
                onSearchTap: _openSearchModal,
                onStartChat: _startChat,
              ),
              Expanded(
                child: IndexedStack(
                  index: shell.selectedTab,
                  children: [
                    ConversationListWidget(
                      onConversationSelected: _openConversation,
                      selectedConversation: shell.selectedConversation,
                    ),
                    PcContactList(
                      onUserSelected: _openUser,
                      onConversationSelected: _openConversation,
                      onOpenPage: _openPage,
                    ),
                    const _WorkTabPlaceholder(),
                    PcDiscoveryList(
                      onConversationSelected: _openConversation,
                      onOpenPage: _openPage,
                    ),
                    const MeTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 中栏头部:搜索框 + “+”菜单(发起聊天/添加朋友),参照微信 PC 的搜索区形态。
class _MiddleColumnHeader extends StatelessWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onStartChat;

  const _MiddleColumnHeader({required this.onSearchTap, required this.onStartChat});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: PcTheme.headerHeight,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      alignment: Alignment.center,
      child: Row(
        children: [
          Expanded(
            child: HoverBuilder(
              cursor: SystemMouseCursors.click,
              builder: (context, hovered) => GestureDetector(
                onTap: onSearchTap,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: hovered ? const Color(0xFFD5D4D3) : PcTheme.searchFieldBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_rounded, size: 15, color: PcTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(l10n.search, style: const TextStyle(fontSize: 12, color: PcTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _PlusMenuButton(onStartChat: onStartChat),
        ],
      ),
    );
  }
}

class _PlusMenuButton extends StatelessWidget {
  final VoidCallback onStartChat;

  const _PlusMenuButton({required this.onStartChat});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      offset: const Offset(0, 34),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'chat',
          height: 36,
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 17, color: PcTheme.textSecondary),
              const SizedBox(width: 10),
              Text(l10n.startChat),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'add',
          height: 36,
          child: Row(
            children: [
              const Icon(Icons.person_add_alt_outlined, size: 17, color: PcTheme.textSecondary),
              const SizedBox(width: 10),
              Text(l10n.addFriend),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'chat':
            onStartChat();
            break;
          case 'add':
            showSearch(context: context, delegate: SearchUserDelegate());
            break;
        }
      },
      child: HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hovered) => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: hovered ? const Color(0xFFD5D4D3) : PcTheme.searchFieldBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.add, size: 18, color: Color(0xFF5C5C5C)),
        ),
      ),
    );
  }
}

class _PcSideBar extends StatelessWidget {
  final void Function(int tab) onTabSelected;

  const _PcSideBar({required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    var shell = Provider.of<PCShellViewModel>(context);
    final l10n = AppLocalizations.of(context)!;
    // macOS 隐藏标题栏后红绿灯悬浮在侧栏顶部,首个元素下移避让
    final double topInset = Platform.isMacOS ? PcTheme.sidebarTopInsetMac : 20;
    return Container(
      color: PcTheme.sidebarBg,
      child: Column(
        children: [
          SizedBox(height: topInset),
          _buildAvatar(context, shell),
          const SizedBox(height: 18),
          Selector<ConversationListViewModel, int>(
            selector: (_, model) => model.unreadMessageCount,
            builder: (context, unreadCount, _) => _SideBarTab(
              tab: PCShellViewModel.tabChat,
              selectedIcon: Icons.chat_bubble_rounded,
              normalIcon: Icons.chat_bubble_outline_rounded,
              tooltip: l10n.tabChat,
              badgeCount: unreadCount,
              onTabSelected: onTabSelected,
            ),
          ),
          const SizedBox(height: 6),
          Selector<ContactListViewModel, int>(
            selector: (_, model) => model.unreadFriendRequestCount,
            builder: (context, unreadFriendRequestCount, _) => _SideBarTab(
              tab: PCShellViewModel.tabContact,
              selectedIcon: Icons.contacts_rounded,
              normalIcon: Icons.contacts_outlined,
              tooltip: l10n.tabContact,
              badgeCount: unreadFriendRequestCount > 0 ? -1 : 0,
              onTabSelected: onTabSelected,
            ),
          ),
          if (Config.WORKSPACE_URL.isNotEmpty) ...[
            const SizedBox(height: 6),
            _SideBarTab(
              tab: PCShellViewModel.tabWork,
              selectedIcon: Icons.grid_view_rounded,
              normalIcon: Icons.grid_view_outlined,
              tooltip: l10n.tabWork,
              onTabSelected: onTabSelected,
            ),
          ],
          const SizedBox(height: 6),
          _SideBarTab(
            tab: PCShellViewModel.tabDiscovery,
            selectedIcon: Icons.explore_rounded,
            normalIcon: Icons.explore_outlined,
            tooltip: l10n.tabDiscovery,
            onTabSelected: onTabSelected,
          ),
          const Spacer(),
          _SideBarTab(
            tab: PCShellViewModel.tabMe,
            selectedIcon: Icons.person_rounded,
            normalIcon: Icons.person_outline_rounded,
            tooltip: l10n.tabMe,
            onTabSelected: onTabSelected,
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, PCShellViewModel shell) {
    return Consumer<UserViewModel>(
      builder: (context, userViewModel, _) {
        var userInfo = userViewModel.getUserInfo(Imclient.currentUserId);
        return HoverBuilder(
          cursor: SystemMouseCursors.click,
          builder: (context, hovered) => GestureDetector(
            onTap: () => onTabSelected(PCShellViewModel.tabMe),
            child: Portrait(
              userInfo.portrait ?? Config.defaultUserPortrait,
              Config.defaultUserPortrait,
              width: 34,
              height: 34,
              borderRadius: 4,
            ),
          ),
        );
      },
    );
  }
}

class _SideBarTab extends StatelessWidget {
  final int tab;
  final IconData selectedIcon;
  final IconData normalIcon;
  final String tooltip;
  final void Function(int tab) onTabSelected;

  /// 0 不显示;-1 只显示红点;>0 显示数字。
  final int badgeCount;

  const _SideBarTab({
    required this.tab,
    required this.selectedIcon,
    required this.normalIcon,
    required this.tooltip,
    required this.onTabSelected,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    var shell = Provider.of<PCShellViewModel>(context);
    bool selected = shell.selectedTab == tab;

    return Tooltip(
      message: tooltip,
      child: HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hovered) {
          Widget icon = Icon(
            selected ? selectedIcon : normalIcon,
            size: 22,
            color: selected
                ? PcTheme.accent
                : hovered
                    ? PcTheme.sidebarIconHover
                    : PcTheme.sidebarIcon,
          );
          if (badgeCount != 0) {
            icon = badge.Badge(
              position: badge.BadgePosition.topEnd(top: -5, end: -9),
              badgeContent: badgeCount == -1
                  ? null
                  : Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
              badgeStyle: const badge.BadgeStyle(badgeColor: PcTheme.badgeRed, padding: EdgeInsets.all(4)),
              child: icon,
            );
          }
          return GestureDetector(
            onTap: () => onTabSelected(tab),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: hovered && !selected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(child: icon),
            ),
          );
        },
      ),
    );
  }
}

/// 工作台在右栏整栏展示(网页形态),中栏只留占位说明。
class _WorkTabPlaceholder extends StatelessWidget {
  const _WorkTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(context)!.tabWork,
        style: const TextStyle(fontSize: 13, color: PcTheme.textTertiary),
      ),
    );
  }
}

/// 未选中会话时的右栏空状态:浅灰底 + 低调的应用图标水印。
class _EmptyDetailPane extends StatelessWidget {
  const _EmptyDetailPane();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PcTheme.chatBg,
      child: Center(
        child: Opacity(
          opacity: 0.10,
          child: Image.asset('assets/images/app_icon.png', width: 72, height: 72),
        ),
      ),
    );
  }
}
