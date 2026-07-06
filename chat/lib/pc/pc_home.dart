import 'package:badges/badges.dart' as badge;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/contact/contact_list_widget.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/contact/search_user.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/home/conversation_list_widget.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/search/search_portal_delegate.dart';
import 'package:chat/settings/me_tab.dart';
import 'package:chat/user_info_widget.dart';
import 'package:chat/viewmodel/contact_list_view_model.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 桌面端三栏 Shell:侧栏(tab 切换)+ 中栏(会话/联系人列表)+ 右栏(嵌套 Navigator 的详情区)。
/// 会话/联系人点击通过回调注入,在右栏内打开;二级页面(群信息等)在右栏内部导航。
class PCHome extends StatefulWidget {
  const PCHome({super.key});

  @override
  State<PCHome> createState() => _PCHomeState();
}

class _PCHomeState extends State<PCHome> {
  static const double _sideBarWidth = 64;
  static const double _middleColumnWidth = 300;

  final GlobalKey<NavigatorState> _paneNavKey = GlobalKey<NavigatorState>();
  final PCShellViewModel _shellViewModel = PCShellViewModel();

  @override
  void dispose() {
    _shellViewModel.dispose();
    super.dispose();
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

  void _openConversation(Conversation conversation) {
    if (_shellViewModel.selectedConversation == conversation) {
      return;
    }
    _shellViewModel.selectConversation(conversation);
    _paneNavKey.currentState!.pushAndRemoveUntil(
      _paneRoute(ConversationScreen(conversation, key: ValueKey(conversation))),
      (route) => route.isFirst,
    );
  }

  void _openUser(String userId) {
    _shellViewModel.selectConversation(null);
    _paneNavKey.currentState!.pushAndRemoveUntil(
      _paneRoute(UserInfoWidget(userId, key: ValueKey('pc-user-$userId'))),
      (route) => route.isFirst,
    );
  }

  void _startChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PickUserScreen(title: AppLocalizations.of(context)!.startChat, (pickerContext, members) async {
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
                    Navigator.pop(pickerContext); // 关闭选人页
                    _openConversation(Conversation(conversationType: ConversationType.Group, target: strValue));
                  }, (errorCode) {
                    Navigator.pop(pickerContext);
                    Fluttertoast.showToast(msg: '创建失败：$errorCode');
                  });
                }
              })),
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
    return ChangeNotifierProvider<PCShellViewModel>.value(
      value: _shellViewModel,
      child: Scaffold(
        body: Row(
          children: [
            const SizedBox(width: _sideBarWidth, child: _PCSideBar()),
            SizedBox(width: _middleColumnWidth, child: _buildMiddleColumn(context)),
            Container(width: 0.5, color: const Color(0xffe0e0e0)),
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
    );
  }

  Widget _buildMiddleColumn(BuildContext context) {
    return Consumer<PCShellViewModel>(
      builder: (context, shell, _) {
        return IndexedStack(
          index: shell.selectedTab,
          children: [
            Column(
              children: [
                _buildMiddleHeader(context, AppLocalizations.of(context)!.tabChat),
                Expanded(
                  child: ConversationListWidget(
                    onConversationSelected: _openConversation,
                    selectedConversation: shell.selectedConversation,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                _buildMiddleHeader(context, AppLocalizations.of(context)!.tabContact),
                Expanded(child: ContactListWidget(onUserSelected: _openUser)),
              ],
            ),
            const MeTab(),
          ],
        );
      },
    );
  }

  Widget _buildMiddleHeader(BuildContext context, String title) {
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: const BoxDecoration(
        color: Color(0xfff7f7f7),
        border: Border(bottom: BorderSide(color: Color(0xffe0e0e0), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 22),
            onPressed: () => showSearch(context: context, delegate: SearchPortalDelegate()),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
            offset: const Offset(0, 40),
            itemBuilder: (context) {
              return [
                PopupMenuItem(
                  value: "chat",
                  child: ListTile(
                    leading: const Icon(Icons.chat_bubble_rounded),
                    title: Text(AppLocalizations.of(context)!.startChat),
                  ),
                ),
                PopupMenuItem(
                  value: "add",
                  child: ListTile(
                    leading: const Icon(Icons.contact_phone_rounded),
                    title: Text(AppLocalizations.of(context)!.addFriend),
                  ),
                ),
              ];
            },
            onSelected: (value) {
              switch (value) {
                case "chat":
                  _startChat();
                  break;
                case "add":
                  showSearch(context: context, delegate: SearchUserDelegate());
                  break;
              }
            },
          ),
        ],
      ),
    );
  }
}

class _PCSideBar extends StatelessWidget {
  const _PCSideBar();

  static const Color _selectedColor = Color(0xff3B9AFF);
  static const Color _normalColor = Color(0xff969696);

  @override
  Widget build(BuildContext context) {
    var shell = Provider.of<PCShellViewModel>(context);
    return Container(
      color: const Color(0xff2e2e2e),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Consumer<UserViewModel>(
            builder: (context, userViewModel, _) {
              var userInfo = userViewModel.getUserInfo(Imclient.currentUserId);
              return Portrait(
                userInfo.portrait ?? Config.defaultUserPortrait,
                Config.defaultUserPortrait,
                width: 36,
                height: 36,
                borderRadius: 4,
              );
            },
          ),
          const SizedBox(height: 24),
          Selector<ConversationListViewModel, int>(
            selector: (_, model) => model.unreadMessageCount,
            builder: (context, unreadCount, _) => _buildTabIcon(
              context,
              shell,
              PCShellViewModel.tabChat,
              Icons.chat_bubble_rounded,
              Icons.chat_bubble_outline_rounded,
              AppLocalizations.of(context)!.tabChat,
              badgeCount: unreadCount,
            ),
          ),
          Selector<ContactListViewModel, int>(
            selector: (_, model) => model.unreadFriendRequestCount,
            builder: (context, unreadFriendRequestCount, _) => _buildTabIcon(
              context,
              shell,
              PCShellViewModel.tabContact,
              Icons.contacts_rounded,
              Icons.contacts_outlined,
              AppLocalizations.of(context)!.tabContact,
              badgeCount: unreadFriendRequestCount > 0 ? -1 : 0,
            ),
          ),
          const Spacer(),
          _buildTabIcon(
            context,
            shell,
            PCShellViewModel.tabMe,
            Icons.person_rounded,
            Icons.person_outline_rounded,
            AppLocalizations.of(context)!.tabMe,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTabIcon(BuildContext context, PCShellViewModel shell, int tab, IconData selectedIcon, IconData normalIcon, String tooltip,
      {int badgeCount = 0}) {
    bool selected = shell.selectedTab == tab;
    Widget icon = Icon(
      selected ? selectedIcon : normalIcon,
      color: selected ? _selectedColor : _normalColor,
      size: 26,
    );
    if (badgeCount != 0) {
      // badgeCount 为 -1 时只显示红点(好友请求),与移动端 HomeTabBar 一致
      icon = badge.Badge(
        position: badge.BadgePosition.topEnd(top: -4, end: -8),
        badgeContent: badgeCount == -1
            ? null
            : Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
        badgeStyle: const badge.BadgeStyle(badgeColor: Colors.red),
        child: icon,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: IconButton(
        tooltip: tooltip,
        icon: icon,
        onPressed: () => shell.selectTab(tab),
      ),
    );
  }
}

class _EmptyDetailPane extends StatelessWidget {
  const _EmptyDetailPane();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xfff5f5f5),
      body: Center(
        child: Icon(Icons.forum_outlined, size: 80, color: Colors.black12),
      ),
    );
  }
}
