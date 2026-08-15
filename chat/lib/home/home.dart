// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:badges/badges.dart' as badge;
import '../widgets/unread_badge.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/imclient_platform.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/call/conference/join_conference_view.dart';
import 'package:avenginekit/engine/avenginekit.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/config.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/pad/pad_workspace_welcome.dart';
import 'package:chat/contact/search_user.dart';
import 'package:chat/search/search_portal_delegate.dart';
import 'package:chat/settings/me_tab.dart';
import 'package:chat/viewmodel/contact_list_view_model.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/workspace/work_space.dart';
import 'package:chat/scanner/qr_scanner_screen.dart';
import 'package:chat/group/group_info_screen.dart';
import 'package:chat/user_info_widget.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/widget/popup_menu_overlay.dart';

import 'package:chat/wfc_scheme.dart';
import 'package:chat/pc/pc_login_screen.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/l10n/app_localizations.dart';

import '../contact/contact_list_widget.dart';
import '../discovery/discovery_tab.dart';
import 'conversation_list_widget.dart';
import 'package:chat/app_shell.dart';

/// 移动端主界面:五个 tab 的 PageView + 底部栏。平板两栏时它整体就是左栏。
///
/// [twoPane] 与 [onTabChanged] 只有平板会传:手机与 PC 拿默认值,构造路径与
/// 引入平板之前逐位相同。
class HomeTabBar extends StatefulWidget {
  /// 处于两栏形态(平板宽栏):详情去右栏,工作台 tab 的本栏换成欢迎页。
  final bool twoPane;

  /// 当前 tab 变了。平板据此切换右栏 —— 每个 tab 有各自独立的详情栈。
  final ValueChanged<int>? onTabChanged;

  const HomeTabBar({Key? key, this.twoPane = false, this.onTabChanged})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => HomeTabBarState();
}

class HomeTabBarState extends State<HomeTabBar> {
  late List<String> appBarTitles;
  final tabTextStyleSelected = const TextStyle(color: Color(0xff3B9AFF));
  final tabTextStyleNormal = const TextStyle(color: Color(0xff969696));

  Color themeColor = Colors.orange;
  int _tabIndex = 0;
  final GlobalKey _plusButtonKey = GlobalKey();

  /// 消息 tab 会话列表的滚动控制器（移动端），用于双击 tab 滚动到第一个未读会话
  final ScrollController _conversationScrollController = ScrollController();

  /// 上一次点击消息 tab 的时间，用于识别双击
  DateTime? _lastChatTabTapTime;

  var tabImages;
  var _body;
  var pages;
  PageController? _pageController;

  Image getTabImage(path) {
    return Image.asset(path, width: 20.0, height: 20.0);
  }

  /// 当前 tab。跨断点时本 State 会被整棵搬移(见 AppHome 的 GlobalKey),
  /// 新建出来的 PadHome 靠它对齐右栏,不然左栏停在"发现"、右栏却是"消息"那一叠。
  int get tabIndex => _tabIndex;

  /// 切 tab 的唯一入口:底部栏点击与 PageView 滑动都走这里,
  /// 免得两处各自 setState 却漏掉通知外层(平板右栏就是靠这个通知跟着换的)。
  void _setTabIndex(int index) {
    if (_tabIndex == index) {
      return;
    }
    setState(() {
      _tabIndex = index;
    });
    widget.onTabChanged?.call(index);
  }

  /// 工作台 tab 在 [pages] 里的下标;没配工作台地址时它整个不存在,返回 -1。
  int get _workspaceTabIndex => (Config.workspaceUrl ?? '').isEmpty ? -1 : 2;

  /// 顶部右上角的搜索与加号只属于消息、通讯录这两个 tab —— 工作台、发现、我
  /// 都不是可搜索的列表,也没有"发起聊天 / 加好友 / 扫一扫"的语境。
  ///
  /// 认下标 0、1 而不是"除了最后一个":工作台缺席只会让它**之后**的 tab 前移,
  /// 前两个 tab 的下标恒定。
  bool get _showAppBarActions => _tabIndex <= 1;

  /// 我 tab 用空标题栏(无标题、与下面的个人资料卡同色连成一片,对齐微信)。
  ///
  /// 只在单栏时这么做:平板两栏下左栏只有 [kPadListColumnWidth] 宽、右边紧挨着
  /// 详情栏,空着的标题栏看起来像没加载出来,所以平板的我 tab 与其它 tab 一样
  /// 正常显示标题。
  bool get _bareMeAppBar => _tabIndex == pages.length - 1 && !widget.twoPane;

  /// 本栏(两栏形态下即左栏)实际要渲染的五个页面。
  ///
  /// 只有工作台不一样:两栏时它的正文是一整个网页,挤在 320 宽的左栏里没法看,
  /// 所以左栏换成欢迎页,真正的工作台由右栏承载(见 PadHome)。
  List<Widget> get _visiblePages {
    if (!widget.twoPane || _workspaceTabIndex < 0) {
      return pages;
    }
    return List<Widget>.of(pages)
      ..[_workspaceTabIndex] = const _KeepAliveWrapper(
        child: PadWorkspaceWelcome(),
      );
  }

  @override
  void initState() {
    super.initState();
    appBarTitles = [];
    pages = <Widget>[
      _KeepAliveWrapper(
          child: ConversationListWidget(
              scrollController: _conversationScrollController)),
      _KeepAliveWrapper(child: ContactListWidget()),
      const _KeepAliveWrapper(child: WorkSpace()),
      const _KeepAliveWrapper(child: DiscoveryTab()),
      const _KeepAliveWrapper(child: MeTab())
    ];
    tabImages = [
      [
        getTabImage('assets/images/tabbar_chat.png'),
        getTabImage('assets/images/tabbar_chat_cover.png')
      ],
      [
        getTabImage('assets/images/tabbar_contact.png'),
        getTabImage('assets/images/tabbar_contact_cover.png')
      ],
      [
        getTabImage('assets/images/tabbar_work.png'),
        getTabImage('assets/images/tabbar_work_cover.png')
      ],
      [
        getTabImage('assets/images/tabbar_discover.png'),
        getTabImage('assets/images/tabbar_discover_cover.png')
      ],
      [
        getTabImage('assets/images/tabbar_me.png'),
        getTabImage('assets/images/tabbar_me_cover.png')
      ]
    ];
    _pageController = PageController(initialPage: _tabIndex);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _conversationScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appBarTitles = [
      AppLocalizations.of(context)!.tabChat,
      AppLocalizations.of(context)!.tabContact,
      AppLocalizations.of(context)!.tabWork,
      AppLocalizations.of(context)!.tabDiscovery,
      AppLocalizations.of(context)!.tabMe
    ];

    if ((Config.workspaceUrl ?? '').isEmpty) {
      if (appBarTitles.length > 2) {
        appBarTitles.removeAt(2);
      }
      if (pages.length > 2) {
        pages.removeAt(2);
      }
      if (tabImages.length > 2) {
        tabImages.removeAt(2);
      }
    }
  }

  TextStyle getTabTextStyle(int curIndex) {
    if (curIndex == _tabIndex) {
      return tabTextStyleSelected;
    }
    return tabTextStyleNormal;
  }

  Image getTabIcon(int curIndex) {
    if (curIndex == _tabIndex) {
      return tabImages[curIndex][1];
    }
    return tabImages[curIndex][0];
  }

  String getTabTitle(int curIndex) {
    return appBarTitles[curIndex];
  }

  void _onTapSearchButton(BuildContext context) {
    openSearch(
        context,
        SearchPortalDelegate(
            searchFieldHint: AppLocalizations.of(context)!.pleaseInput));
  }

  /// 双击消息 tab：把第一个有未读的会话滚动到列表顶部
  void _scrollToFirstUnreadConversation() {
    final model =
        Provider.of<ConversationListViewModel>(context, listen: false);
    final list = model.conversationList;
    int target = -1;
    for (int i = 0; i < list.length; i++) {
      final unread = list[i].unreadCount;
      if (unread.unread + unread.unreadMention + unread.unreadMentionAll > 0) {
        target = i;
        break;
      }
    }
    if (target < 0 || !_conversationScrollController.hasClients) return;
    final extent = conversationItemExtent(context);
    final offset = (target * extent)
        .clamp(0.0, _conversationScrollController.position.maxScrollExtent);
    _conversationScrollController.animateTo(offset,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _dismissProcessingDialog(BuildContext context) {
    // showDialog 默认压在**根** Navigator 上,关它也必须指名根 —— 手机上只有一个
    // Navigator,两者是同一个;平板两栏时 context 落在右栏那条嵌套栈里,
    // 不指名的话弹掉的是右栏当前页,而"正在建群"的圈会一直转下去。
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _showProcessingDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      barrierDismissible: false, // 阻止用户点击外部关闭对话框
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

  void _startChat() {
    openPage(
      context,
      PickUserScreen(title: AppLocalizations.of(context)!.startChat,
          (context, members) async {
        if (members.isEmpty) {
          showToast(msg: AppLocalizations.of(context)!.pickFriendsToStartChat);
        } else if (members.length == 1) {
          Conversation conversation = Conversation(
              conversationType: ConversationType.Single, target: members[0]);
          replaceWithConversation(context, conversation);
        } else {
                  _showProcessingDialog(
                      context, AppLocalizations.of(context)!.creatingGroup);

                  List<UserInfo> userInfos =
                      await Imclient.getUserInfos(members);
                  UserInfo? creator =
                      await Imclient.getUserInfo(Imclient.currentUserId);
                  String groupName = creator!.displayName!;
                  for (var user in userInfos) {
                    if (user.displayName != null) {
                      if ('$groupName,${user.displayName}'.length > 24) {
                        groupName = AppLocalizations.of(context)!
                            .groupNameTruncatedSuffix(groupName);
                        break;
                      } else {
                        groupName = '$groupName,${user.displayName}';
                      }
                    }
                  }

                  Imclient.createGroup(null, groupName, null,
                      GroupType.Restricted.index, members, (strValue) {
                    _dismissProcessingDialog(context);
                    Conversation conversation = Conversation(
                        conversationType: ConversationType.Group,
                        target: strValue);
                    replaceWithConversation(context, conversation);
                  }, (errorCode) {
                    _dismissProcessingDialog(context);
                    showToast(
                        msg: AppLocalizations.of(context)!
                            .createGroupFail(errorCode));
                  });
                }
              }),
    );
  }

  void _addFriend() {
    openSearch(
        context,
        SearchUserDelegate(
            searchFieldHint:
                AppLocalizations.of(context)!.searchUserFieldHint));
  }

  void _showPlusMenu(BuildContext context) {
    final renderBox =
        _plusButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final targetRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;

    PopupMenuOverlay.show(
      context: context,
      targetRect: targetRect,
      listMode: true,
      popupWidth: 160,
      menuItems: [
        {
          'label': AppLocalizations.of(context)!.startChat,
          'value': 'chat',
          'icon': Icons.chat_bubble_rounded,
        },
        {
          'label': AppLocalizations.of(context)!.addFriend,
          'value': 'add',
          'icon': Icons.contact_phone_rounded,
        },
        {
          'label': AppLocalizations.of(context)!.scanQrCode,
          'value': 'scan',
          'icon': Icons.qr_code_scanner_rounded,
        },
      ],
      onItemTap: (value) {
        switch (value) {
          case 'chat':
            _startChat();
            break;
          case 'add':
            _addFriend();
            break;
          case 'scan':
            _scanQrCode();
            break;
        }
      },
    );
  }

  void _scanQrCode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QRScannerScreen()),
      );

      if (result != null && result is String) {
        if (mounted) {
          _handleQrCode(result);
        }
      }
    } catch (e) {
      if (mounted) {
        showToast(msg: AppLocalizations.of(context)!.scanFail(e.toString()));
      }
    }
  }

  void _handleQrCode(String qrcode) {
    if (qrcode.isEmpty) return;

    String prefix;
    String value;

    int lastSlashIndex = qrcode.lastIndexOf('/');
    if (lastSlashIndex >= 0 && lastSlashIndex < qrcode.length - 1) {
      prefix = qrcode.substring(0, lastSlashIndex + 1);
      int questionMarkIndex = qrcode.indexOf('?');
      if (questionMarkIndex > lastSlashIndex) {
        value = qrcode.substring(lastSlashIndex + 1, questionMarkIndex);
      } else {
        value = qrcode.substring(lastSlashIndex + 1);
      }
    } else {
      showToast(msg: AppLocalizations.of(context)!.invalidQrCode(qrcode));
      return;
    }

    switch (prefix) {
      case WfcScheme.qrCodePrefixUser:
        openPage(context, UserInfoWidget(value));
        break;
      case WfcScheme.qrCodePrefixGroup:
        // Parse from parameter if exists
        String? from;
        try {
          Uri uri = Uri.parse(qrcode);
          from = uri.queryParameters['from'];
        } catch (e) {
          // ignore
        }
        openPage(context, GroupInfoScreen(groupId: value, from: from));
        break;
      case WfcScheme.qrCodePrefixPcSession:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => PCLoginScreen(token: value)));
        break;
      case WfcScheme.qrCodePrefixChannel:
        // TODO: Implement Channel
        showToast(msg: AppLocalizations.of(context)!.channelNotSupport);
        break;
      case WfcScheme.qrCodePrefixConference:
        if (avEngineKit.isSupportConference()) {
          String? password;
          try {
            Uri uri = Uri.parse(qrcode);
            password = uri.queryParameters['pwd'];
          } catch (e) {
            // ignore
          }
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      JoinConferenceView(initialConferenceId: value)));
        } else {
          showToast(msg: AppLocalizations.of(context)!.conferenceNotSupport);
        }
        break;
      default:
        showToast(msg: AppLocalizations.of(context)!.scanResult(qrcode));
        break;
    }
  }

  Widget _buildBadge(int count, Widget child) {
    // count == -1 表示好友请求红点(无数字)
    return UnreadBadge(
      count: count,
      position: badge.BadgePosition.topEnd(top: 0, end: -12),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScrollPhysics physics =
        (!AppShell.isPointerInput && WfcPlatform.isAndroid)
            ? const PageScrollPhysics()
            : const NeverScrollableScrollPhysics();
    _body = PageView(
      controller: _pageController,
      physics: physics,
      children: _visiblePages,
      onPageChanged: _setTabIndex,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: context.colors.bottomBarBg,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        //布局结构
        appBar: AppBar(
          backgroundColor: _bareMeAppBar ? context.colors.surface : null,
          elevation: 0,
          //选中每一项的标题和图标设置
          title: _bareMeAppBar ? null : Text(appBarTitles[_tabIndex]),
          centerTitle: false,
          actions: !_showAppBarActions
              ? null
              : [
                  IconButton(
                    onPressed: () => _onTapSearchButton(context),
                    icon: const Icon(Icons.search_rounded),
                  ),
                  IconButton(
                    key: _plusButtonKey,
                    onPressed: () => _showPlusMenu(context),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                  const SizedBox(width: 8),
                ],
        ),
        body: _body,
        bottomNavigationBar: CupertinoTabBar(
          backgroundColor: context.colors.bottomBarBg,
          activeColor: context.colors.accent,
          inactiveColor: context.colors.textSecondary,
          height: 58.0,
          border: Border(
            top: BorderSide(
              color: context.colors.hairlineSoft,
              width: 0.0,
            ),
          ),
          items: List.generate(appBarTitles.length, (index) {
            Widget iconWidget;
            if (index == 0) {
              iconWidget = Selector<ConversationListViewModel, int>(
                selector: (_, model) => model.unreadMessageCount,
                builder: (context, unreadCount, child) =>
                    _buildBadge(unreadCount, getTabIcon(0)),
              );
            } else if (index == 1) {
              iconWidget = Selector<ContactListViewModel, int>(
                selector: (_, model) => model.unreadFriendRequestCount,
                builder: (context, unreadFriendRequestCount, child) =>
                    _buildBadge(
                        unreadFriendRequestCount > 0 ? -1 : 0, getTabIcon(1)),
              );
            } else {
              iconWidget = getTabIcon(index);
            }
            return BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: iconWidget,
              ),
              label: getTabTitle(index),
            );
          }),
          currentIndex: _tabIndex,
          onTap: (index) {
            if (_tabIndex != index) {
              _setTabIndex(index);
              _pageController?.jumpToPage(index);
            } else if (index == 0) {
              // 双击消息 tab：滚动第一个未读会话到顶部（对齐微信）
              final now = DateTime.now();
              final lastTap = _lastChatTabTapTime;
              _lastChatTabTapTime = now;
              if (lastTap != null &&
                  now.difference(lastTap) < const Duration(milliseconds: 300)) {
                _lastChatTabTapTime = null;
                _scrollToFirstUnreadConversation();
              }
            }
          },
        ),
      ),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({Key? key, required this.child}) : super(key: key);

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
