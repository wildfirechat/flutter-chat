import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';

import 'package:chat/app_navigator.dart';
import 'package:chat/config.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/home/home.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/workspace/work_space.dart';

/// 左栏(列表栏)宽度。
///
/// 比 PC 中栏(298)宽一档:平板是触摸设备,行高与留白都走移动端那套(见
/// [AppShell.isDesktopStyle] 为 false),同样的内容需要更多横向空间。
/// 断点 720 时右栏还剩 400,iPad mini 竖屏(744)剩 424,够放下气泡。
const double kPadListColumnWidth = 320;

/// 平板两栏 Shell:左栏整套复用移动端的 [HomeTabBar](五个 tab、底部栏、搜索、
/// 加号菜单原样不动),右栏是详情。
///
/// **每个 tab 一条独立的详情栈**(类微信 Pad,与 hm-chat 的 SplitTabPane 同一套)。
/// 右栏是一叠 [Navigator],每个 tab 一个,用 [IndexedStack] 按当前 tab 选中显示:
/// 在通讯录里点开的用户资料留在通讯录那条栈上,切到消息 tab 看到的是消息自己的
/// 会话,切回来资料还在。共用一条栈的话,切个 tab 右栏就会挂着上一个 tab 的东西。
///
/// **不复用 PCHome**:那是三栏 + 指针交互 + window_manager 的形态,平板要的是
/// 移动端密度与触摸交互下的两栏。共用的只有 [PCShellViewModel] 这个导航状态,
/// 以及 app_navigator.dart 那套"有 Shell 就往右栏开"的分流。
///
/// 右栏详情直接用 [ConversationScreen] —— 它本来就是 Scaffold + AppBar +
/// 共享的 ConversationPane(移动输入栏),放进栏里即是平板要的样子,不需要
/// 另写一套 pane。
class PadHome extends StatefulWidget {
  /// 左栏 [HomeTabBar] 的 key,由 [AppHome] 持有并在两种形态间复用 ——
  /// 断点来回跨时 HomeTabBar 的 State(选中的 tab、列表滚动位置)靠它保住。
  final Key? tabBarKey;

  /// 建出来时左栏停在第几个 tab。由 [AppHome] 从上一形态的 HomeTabBar 读出来传入
  /// —— 本 Widget 是跨断点新建的,自己没有历史,不给就会左右两栏对不上。
  final int initialTabIndex;

  const PadHome({super.key, this.tabBarKey, this.initialTabIndex = 0});

  @override
  State<PadHome> createState() => _PadHomeState();
}

class _PadHomeState extends State<PadHome> {
  /// 五个 tab 各自的详情栈。下标与 [HomeTabBar] 的 tab 下标一一对应。
  late final List<GlobalKey<NavigatorState>> _paneNavKeys;

  /// 当前 tab。左栏的 [HomeTabBar] 通过 onTabChanged 推过来 ——
  /// tab 状态的主仍是 HomeTabBar 自己(手机端也要用),这里只是跟着走。
  int _tabIndex = 0;

  late PCShellViewModel _shell;
  late ConversationListViewModel _conversationListViewModel;

  /// 每条栈的路由表,见 [_PaneRouteTracker]。
  late final List<_PaneRouteTracker> _paneTrackers;

  /// 选中的那个会话页压在**哪条栈**上;没有则 -1。
  ///
  /// 会话被删除时据此找到该清哪一栏。不能只记一个 bool —— 五条栈各自独立,
  /// 会话可能压在一条已经切走的栈上。
  int _conversationPaneTab = -1;

  /// 选中的会话在列表里出现过。新建的会话在发出首条消息前不在列表里,
  /// 不先确认"来过"就清栏,会把刚建的会话立刻关掉。
  bool _selectedSeenInList = false;

  /// 已经建出过右栏的 tab。没来过的 tab 不建 —— 工作台那一栏一建就是个 WebView,
  /// 会去拉远端页面,不该因为"进了平板形态"就白拉一次。
  final Set<int> _materializedTabs = <int>{};

  /// 窄→宽旋转时,要把选中的会话补进哪个 tab 的栈;补完置 -1。
  ///
  /// 不能改成"哪个 tab 首次建栏就补给谁":那样用户过一会儿点进发现 tab,
  /// 那一栏也会莫名其妙冒出个会话页。
  int _seedConversationTabIndex = -1;

  /// 当前 tab 的右栏还能不能返回。系统返回键据此决定是退右栏还是退出 App。
  bool _paneCanPop = false;

  /// tab 数量与下标。工作台没配地址时整个 tab 不存在,后面的 tab 依次前移 ——
  /// 与 [HomeTabBar.didChangeDependencies] 里那段删除逻辑保持同一套口径。
  bool get _hasWorkspaceTab => (Config.workspaceUrl ?? '').isNotEmpty;
  int get _workspaceTabIndex => _hasWorkspaceTab ? 2 : -1;
  int get _tabCount => _hasWorkspaceTab ? 5 : 4;

  @override
  void initState() {
    super.initState();
    _paneNavKeys = List.generate(_tabCount, (_) => GlobalKey<NavigatorState>());
    _paneTrackers =
        List.generate(_tabCount, (_) => _PaneRouteTracker(_onPaneStackChanged));
    _tabIndex = widget.initialTabIndex.clamp(0, _tabCount - 1);
    _materializedTabs.add(_tabIndex);
    _conversationListViewModel =
        Provider.of<ConversationListViewModel>(context, listen: false);
    _conversationListViewModel.addListener(_onConversationListChanged);
    // Shell 状态是应用级的(main.dart 注册),这里只注入打开器。
    // **刻意不 reset**:窄→宽旋转会重建本 Widget,reset 会把用户正在看的会话丢掉。
    // 跨账号的残留由 AppHome 在登录态切换时清理。
    _shell = context.read<PCShellViewModel>();
    // 窄栏下选中的会话由本次建出来的那个 tab 接手,见 [_initialPaneRoutes]
    if (_shell.selectedConversation != null &&
        _tabIndex != _workspaceTabIndex) {
      _seedConversationTabIndex = _tabIndex;
    }
    _claimOpeners();
  }

  /// 把 Shell 上的打开器认领到自己身上。
  ///
  /// 每帧都重认一次,而不是只在 initState 认一次:这几个是 Shell 上的可变字段,
  /// 任何一次 `reset()`(换账号、另一个 home 实例被建出来)都会把它们清成 null,
  /// 而清掉之后的表现是**点会话没反应** —— 不抛异常、不留日志。PC 端为此踩过一次
  /// (见 login_form_controller 里的注释),平板又踩了一次。重认的成本是几次引用比较,
  /// 换掉这一整类静默失效。
  void _claimOpeners() {
    _shell.conversationOpener = _openConversation;
    _shell.pageOpener = _openPage;
    _shell.paneCloser = _closePane;
    _shell.paneNavigatorProvider = _currentPaneNavigator;
  }

  @override
  void dispose() {
    _conversationListViewModel.removeListener(_onConversationListChanged);
    // 路由替换时新实例先 initState、旧的后 dispose,只清掉仍属于自己的打开器
    if (_shell.conversationOpener == _openConversation) {
      _shell.conversationOpener = null;
    }
    if (_shell.pageOpener == _openPage) {
      _shell.pageOpener = null;
    }
    if (_shell.paneCloser == _closePane) {
      _shell.paneCloser = null;
    }
    if (_shell.paneNavigatorProvider == _currentPaneNavigator) {
      _shell.paneNavigatorProvider = null;
    }
    super.dispose();
  }

  NavigatorState? _currentPaneNavigator() =>
      _paneNavKeys[_tabIndex].currentState;

  void _onTabChanged(int index) {
    if (index < 0 || index >= _paneNavKeys.length || index == _tabIndex) {
      return;
    }
    setState(() {
      _tabIndex = index;
      _materializedTabs.add(index);
      // 换了一栏,能不能返回也跟着换 —— 新那栏的 Navigator 这一帧才建出来的话
      // 读到 null,按不能返回算,建好后 NavigationNotification 会再纠正一次
      _paneCanPop = _paneNavKeys[index].currentState?.canPop() ?? false;
    });
  }

  /// 当前栏的可返回状态变了就重算。
  ///
  /// 触发源是子树里冒上来的 [NavigationNotification]:五条栈都会发,但这里只认
  /// 当前那条,别的栈发的通知顶多让我们多算一次。
  void _syncPaneCanPop() {
    final bool next = _currentPaneNavigator()?.canPop() ?? false;
    if (next == _paneCanPop || !mounted) {
      return;
    }
    setState(() {
      _paneCanPop = next;
    });
  }

  /// 右栏内不做转场动画:两栏形态下详情是"换内容"而不是"翻页"。
  Route<dynamic> _paneRoute(Widget page, [RouteSettings? settings]) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  /// 把 [page] 设成当前 tab 右栏的内容(**替换**掉上一个),底下始终垫着占位页。
  ///
  /// 这是"从左栏选了另一个东西"的语义:换一个联系人、换一个发现入口,右栏是换内容
  /// 而不是叠一层。往下钻一层用的是 [_pushPane]。
  ///
  /// 占位页不能省:少了它栈里就只剩一个路由,页面自己调 `Navigator.pop()` 关闭
  /// 自己时(建群完成、表单提交后)弹不动,会卡在那儿。
  void _setPaneRoot(Widget page, [RouteSettings? settings]) {
    _currentPaneNavigator()?.pushAndRemoveUntil(
        _paneRoute(page, settings), (route) => route.isFirst);
  }

  void _openConversation(Conversation conversation, {int? toFocusMessageId}) {
    final navigator = _currentPaneNavigator();
    if (navigator == null) {
      return;
    }
    final tracker = _paneTrackers[_tabIndex];
    // 栈顶已经是会话 → 原地换一条(在会话之间点来点去不该越叠越深,与 PC 一致);
    // 否则**压入** —— 从某人的资料页点「发消息」,资料页要留在下面,返回回得去。
    final bool replaceTop = tracker.topIsConversation;
    // 新会话页之下除了占位页还有别的东西,才长返回键:消息 tab 直接点开的会话
    // 下面只有占位页,返回过去是一片空白,不该给返回键。
    final bool showBack = tracker.hasRealRouteBelowTop(replacingTop: replaceTop);

    _shell.selectConversation(conversation);
    _conversationPaneTab = _tabIndex;
    // 打开的若是列表里已有的会话,立即记为「来过」,它被删掉时才能可靠清栏;
    // 新建的会话保持 false,等它发出首条消息进列表后由列表回调置真。
    _selectedSeenInList = _conversationListViewModel.conversationList
        .any((info) => info.conversation == conversation);

    // 会话在**当前 tab** 的栈里打开:从通讯录点「发消息」,聊天就该出现在通讯录
    // 这一栏 —— 而不是把人甩到消息 tab 去。
    final route = _paneRoute(
      _conversationPane(conversation, toFocusMessageId, showBack: showBack),
      const RouteSettings(name: kConversationRouteName),
    );
    if (replaceTop) {
      navigator.pushReplacement(route);
    } else {
      navigator.push(route);
    }
  }

  void _openPage(Widget page) {
    _setPaneRoot(page);
  }

  /// 选中的会话被删除(在列表里出现过、现在没了)时,取消选中;
  /// 若某条栈上正压着它,把那一页弹掉 —— 否则会停在一个已经不存在的会话里继续打字。
  void _onConversationListChanged() {
    final selected = _shell.selectedConversation;
    if (selected == null ||
        selected.conversationType == ConversationType.Chatroom) {
      return;
    }
    final exists = _conversationListViewModel.conversationList
        .any((info) => info.conversation == selected);
    if (exists) {
      _selectedSeenInList = true;
      return;
    }
    if (!_selectedSeenInList) {
      return;
    }
    _selectedSeenInList = false;
    final int tab = _conversationPaneTab;
    _shell.selectConversation(null);
    if (tab < 0) {
      return;
    }
    // 只弹会话那一页,不清整条栈:它下面可能垫着通讯录点进来的资料页,
    // 那一页没失效,该露出来而不是跟着一起没。
    final navigator = _paneNavKeys[tab].currentState;
    if (_paneTrackers[tab].topIsConversation && (navigator?.canPop() ?? false)) {
      navigator!.pop();
    } else {
      _resetPane(tab);
    }
  }

  /// 右栏当前内容自知失效(如群聊被移出通讯录)时回到空态。
  void _closePane() => _resetPane(_tabIndex);

  void _resetPane(int tab) {
    if (_conversationPaneTab == tab) {
      _conversationPaneTab = -1;
    }
    _shell.selectConversation(null);
    _paneNavKeys[tab].currentState?.popUntil((route) => route.isFirst);
  }

  /// 某条栈变了。会话页从它所在那条栈上彻底消失(点了返回键、被别的页顶掉)时,
  /// 左栏的选中高亮也要跟着撤 —— 否则列表还亮着一个右栏已经不显示的会话。
  void _onPaneStackChanged() {
    final int tab = _conversationPaneTab;
    if (tab < 0 || _paneTrackers[tab].hasConversation) {
      return;
    }
    _conversationPaneTab = -1;
    // observer 回调可能落在 build 期(onGenerateInitialRoutes 里就会 didPush),
    // 此刻 notifyListeners 会炸,推到帧末去做
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 这一帧里又开了新会话就不要越俎代庖
      if (mounted && _conversationPaneTab < 0) {
        _shell.selectConversation(null);
      }
    });
  }

  Widget _conversationPane(Conversation conversation, int? toFocusMessageId,
      {required bool showBack}) {
    return ConversationScreen(
      conversation,
      toFocusMessageId: toFocusMessageId,
      showBackButton: showBack,
      key: ValueKey('pad-conv-${conversation.conversationType.index}-'
          '${conversation.target}-${conversation.line}-${toFocusMessageId ?? 0}'),
    );
  }

  /// 某个 tab 右栏的初始路由栈。
  ///
  /// 占位页打底。**当前这个** tab 额外把窄栏形态下选中的会话叠在上面 —— 旋转成
  /// 两栏时右栏直接接上,不用等一帧再补 push。之所以认"当前 tab"而不是固定认消息
  /// tab:窄栏下的会话可能是从通讯录点进去的,转宽时它该回到通讯录这一栏。
  /// 工作台 tab 的基座就是工作台本身:它没有"列表 → 详情"的层次,
  /// 左栏是欢迎页,网页始终占着右栏。
  List<Route<dynamic>> _initialPaneRoutes(int tabIndex) {
    if (tabIndex == _workspaceTabIndex) {
      return [_paneRoute(const WorkSpace())];
    }
    final selected = _shell.selectedConversation;
    if (tabIndex != _seedConversationTabIndex || selected == null) {
      return [_emptyPaneRoute()];
    }
    _seedConversationTabIndex = -1;
    _conversationPaneTab = tabIndex;
    _selectedSeenInList = _conversationListViewModel.conversationList
        .any((info) => info.conversation == selected);
    return [
      _emptyPaneRoute(),
      _paneRoute(
        // 下面只有占位页,返回过去是一片空白 —— 不给返回键
        _conversationPane(selected, null, showBack: false),
        const RouteSettings(name: kConversationRouteName),
      ),
    ];
  }

  Route<dynamic> _emptyPaneRoute() => _paneRoute(
      const _PadEmptyPane(), const RouteSettings(name: _kPadEmptyRouteName));

  /// 系统返回键作用到当前 tab 的右栏。弹回占位页(栈里只剩它)时顺手清掉选中态,
  /// 否则左栏还高亮着一个右栏已经不显示的会话,旋转到窄栏还会把它又推出来。
  void _popPane() {
    final navigator = _currentPaneNavigator();
    if (navigator == null) {
      return;
    }
    // 只管弹。左栏的选中高亮由 [_onPaneStackChanged] 按"会话页还在不在栈上"来撤 ——
    // 五条栈各自独立,不能一见这条栈弹空了就把别条栈上开着的会话也取消选中。
    navigator.maybePop();
  }

  /// 一个 tab 的右栏。没进过的 tab 先留空,进过一次就一直挂着。
  Widget _pane(int tabIndex) {
    if (!_materializedTabs.contains(tabIndex)) {
      return const SizedBox.shrink();
    }
    return Navigator(
      key: _paneNavKeys[tabIndex],
      observers: [_paneTrackers[tabIndex]],
      onGenerateRoute: (settings) =>
          _paneRoute(const _PadEmptyPane(), settings),
      onGenerateInitialRoutes: (_, __) => _initialPaneRoutes(tabIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    _claimOpeners();
    return Scaffold(
      // 键盘由**右栏**自己让位。默认的 true 会把整个 body(两栏一起)缩短,
      // 左栏底部的 tab 栏就被顶到键盘上面去了;而且 Scaffold 缩身的同时会把
      // viewInsets 从 body 里抹掉,右栏那些真正需要让位的组件(输入栏、表情面板
      // 的高度缓存)反而读不到键盘高度。
      // 关掉之后:整行保持满高 → 左栏由 [_KeyboardInsetShield] 挡掉键盘,
      // 右栏的 ConversationScreen 自己那层 Scaffold 照常避让,与手机上一致。
      resizeToAvoidBottomInset: false,
      body: Row(
        children: [
          SizedBox(
            width: kPadListColumnWidth,
            child: _KeyboardInsetShield(
              child: HomeTabBar(
                key: widget.tabBarKey,
                twoPane: true,
                onTabChanged: _onTabChanged,
              ),
            ),
          ),
          VerticalDivider(
              width: 0.5, thickness: 0.5, color: context.colors.hairline),
          Expanded(
            // 系统返回键默认只认根 Navigator,不接这一层,在右栏里点开群资料后
            // 按返回会直接退出 App。PC 端没有返回键,所以 PCHome 不需要这个。
            //
            // 这里没用 NavigatorPopHandler:它是"一个 PopScope 配一条嵌套栈"的,
            // 五条栈就会有五个 PopScope 注册到同一条外层路由上,按一次返回键会把
            // 没露面的那几栏也一起弹掉。改成整块一个 PopScope,只作用于当前那栏。
            child: NotificationListener<NavigationNotification>(
              onNotification: (_) {
                _syncPaneCanPop();
                return false;
              },
              child: PopScope(
                canPop: !_paneCanPop,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) {
                    _popPane();
                  }
                },
                // IndexedStack 而不是按 _tabIndex 只建一个:切走的 tab 那条栈要
                // **活着**,切回来才还在原处。它们各自持有 WebView、消息列表这类
                // 重状态,每次切 tab 重建一遍既慢又会丢滚动位置。
                child: IndexedStack(
                  index: _tabIndex,
                  children: [
                    for (int i = 0; i < _tabCount; i++) _pane(i),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 右栏占位页的路由名。判断"栈顶之下还有没有真页面"时要把它排除掉。
const String _kPadEmptyRouteName = 'pad-empty';

/// 盯着一条右栏栈的路由表。
///
/// [NavigatorState] 不对外暴露栈内容,而右栏有两件事非知道不可:换会话该"替换"
/// 还是"压入"、会话页该不该长返回键。栈里除了 PadHome 自己压的,还有页面自己
/// push 出去的子页(群资料、成员列表…),所以只能靠 observer 如实记一份。
class _PaneRouteTracker extends NavigatorObserver {
  _PaneRouteTracker(this.onChanged);

  /// 栈变了就叫一声。注意它可能在 build 期被调到(初始路由就会 didPush)。
  final VoidCallback onChanged;

  final List<Route<dynamic>> _routes = <Route<dynamic>>[];

  bool get topIsConversation =>
      _routes.isNotEmpty &&
      _routes.last.settings.name == kConversationRouteName;

  bool get hasConversation =>
      _routes.any((r) => r.settings.name == kConversationRouteName);

  /// 新栈顶之下还有没有"真页面"(占位页不算)。
  ///
  /// [replacingTop] 为真表示新页要顶掉当前栈顶,那当前栈顶就不算在"之下"里了。
  /// 工作台那条栈的基座是工作台本身而不是占位页,所以这里按路由名判断而不是按
  /// "是不是第一条"。
  bool hasRealRouteBelowTop({required bool replacingTop}) {
    final int end = replacingTop ? _routes.length - 1 : _routes.length;
    for (int i = 0; i < end; i++) {
      if (_routes[i].settings.name != _kPadEmptyRouteName) {
        return true;
      }
    }
    return false;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    onChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    onChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    onChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final int index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index < 0) {
      if (newRoute != null) {
        _routes.add(newRoute);
      }
    } else if (newRoute == null) {
      _routes.removeAt(index);
    } else {
      _routes[index] = newRoute;
    }
    onChanged();
  }
}

/// 让子树看不见软键盘。
///
/// 键盘是**右栏**在打字时弹出来的,左栏没有理由跟着缩:不挡的话底部 tab 栏会被顶到
/// 键盘上面去,列表也跟着挤扁。挡掉之后左栏按满高排版,键盘只是盖在它下面那一截上
/// —— 与 iPad 上其它双栏应用一致。
///
/// 同时把 `padding.bottom` 从 [MediaQueryData.viewPadding] 补回来:键盘弹起时系统
/// 会把 padding 的底部并进 viewInsets,只清 viewInsets 的话底部 tab 栏会丢掉 home
/// indicator 那一档安全区,贴到屏幕最底下。
///
/// 单独做成一个 Widget 而不是 PadHome 里的一个方法:MediaQuery 是逐帧跟着键盘动画
/// 变的,读在 PadHome.build 里会把右栏那一整叠也拖着一起重建。
class _KeyboardInsetShield extends StatelessWidget {
  const _KeyboardInsetShield({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        viewInsets: mq.viewInsets.copyWith(bottom: 0),
        padding: mq.padding.copyWith(bottom: mq.viewPadding.bottom),
      ),
      child: child,
    );
  }
}

/// 右栏空态:还没选中任何会话时的占位。
/// 与 PCHome 的空态同一套语言(淡化的 App 图标,不加文案)。
class _PadEmptyPane extends StatelessWidget {
  const _PadEmptyPane();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.chatBg,
      body: Center(
        child: Opacity(
          opacity: 0.10,
          child:
              Image.asset('assets/images/app_icon.png', width: 72, height: 72),
        ),
      ),
    );
  }
}
