import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';

import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/home/home.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/viewmodel/conversation_list_view_model.dart';
import 'package:chat/theme/app_colors.dart';

/// 左栏(列表栏)宽度。
///
/// 比 PC 中栏(298)宽一档:平板是触摸设备,行高与留白都走移动端那套(见
/// [AppShell.isDesktopStyle] 为 false),同样的内容需要更多横向空间。
/// 断点 720 时右栏还剩 400,iPad mini 竖屏(744)剩 424,够放下气泡。
const double kPadListColumnWidth = 320;

/// 平板两栏 Shell:左栏整套复用移动端的 [HomeTabBar](五个 tab、底部栏、搜索、
/// 加号菜单原样不动),右栏是一个嵌套 Navigator 承载详情。
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

  const PadHome({super.key, this.tabBarKey});

  @override
  State<PadHome> createState() => _PadHomeState();
}

class _PadHomeState extends State<PadHome> {
  final GlobalKey<NavigatorState> _paneNavKey = GlobalKey<NavigatorState>();
  late PCShellViewModel _shell;
  late ConversationListViewModel _conversationListViewModel;

  /// 右栏当前显示的是不是会话(而不是资料页等)。会话被删除时据此决定要不要清栏。
  bool _paneShowsConversation = false;

  /// 选中的会话在列表里出现过。新建的会话在发出首条消息前不在列表里,
  /// 不先确认"来过"就清栏,会把刚建的会话立刻关掉。
  bool _selectedSeenInList = false;

  @override
  void initState() {
    super.initState();
    _conversationListViewModel =
        Provider.of<ConversationListViewModel>(context, listen: false);
    _conversationListViewModel.addListener(_onConversationListChanged);
    // Shell 状态是应用级的(main.dart 注册),这里只注入打开器。
    // **刻意不 reset**:窄→宽旋转会重建本 Widget,reset 会把用户正在看的会话丢掉。
    // 跨账号的残留由 AppHome 在登录态切换时清理。
    _shell = context.read<PCShellViewModel>();
    _claimOpeners();
  }

  /// 把 Shell 上的三个打开器认领到自己身上。
  ///
  /// 每帧都重认一次,而不是只在 initState 认一次:这三个是 Shell 上的可变字段,
  /// 任何一次 `reset()`(换账号、另一个 home 实例被建出来)都会把它们清成 null,
  /// 而清掉之后的表现是**点会话没反应** —— 不抛异常、不留日志。PC 端为此踩过一次
  /// (见 login_form_controller 里的注释),平板又踩了一次。重认的成本是三次引用比较,
  /// 换掉这一整类静默失效。
  void _claimOpeners() {
    _shell.conversationOpener = _openConversation;
    _shell.pageOpener = _openPage;
    _shell.paneCloser = _closePane;
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
    super.dispose();
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

  /// 把 [page] 设成右栏的当前内容(替换掉上一个),底下始终垫着占位页。
  ///
  /// 占位页不能省:少了它栈里就只剩一个路由,页面自己调 `Navigator.pop()` 关闭
  /// 自己时(建群完成、表单提交后)弹不动,会卡在那儿。代价是 `canPop()` 恒为真、
  /// AppBar 会自动长出返回键 —— 会话页用 `showBackButton: false` 关掉,
  /// 它自己再 push 出去的子页(群资料、成员列表)则照常有返回键。
  void _setPaneRoot(Widget page) {
    _paneNavKey.currentState
        ?.pushAndRemoveUntil(_paneRoute(page), (route) => route.isFirst);
  }

  void _openConversation(Conversation conversation, {int? toFocusMessageId}) {
    _shell.selectTab(PCShellViewModel.tabChat);
    _shell.selectConversation(conversation);
    // 打开的若是列表里已有的会话,立即记为「来过」,它被删掉时才能可靠清栏;
    // 新建的会话保持 false,等它发出首条消息进列表后由列表回调置真。
    _selectedSeenInList = _conversationListViewModel.conversationList
        .any((info) => info.conversation == conversation);
    _paneShowsConversation = true;
    _setPaneRoot(_conversationPane(conversation, toFocusMessageId));
  }

  void _openPage(Widget page) {
    _paneShowsConversation = false;
    _setPaneRoot(page);
  }

  /// 选中的会话被删除(在列表里出现过、现在没了)时,取消选中;
  /// 若右栏正显示的就是它,一并清回空态 —— 否则会停在一个已经不存在的会话里继续打字。
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
    final wasShowingConversation = _paneShowsConversation;
    _shell.selectConversation(null);
    if (wasShowingConversation) {
      _closePane();
    }
  }

  /// 右栏当前内容自知失效(如群聊被移出通讯录)时回到空态。
  void _closePane() {
    _paneShowsConversation = false;
    _shell.selectConversation(null);
    _paneNavKey.currentState?.popUntil((route) => route.isFirst);
  }

  Widget _conversationPane(Conversation conversation, int? toFocusMessageId) {
    return ConversationScreen(
      conversation,
      toFocusMessageId: toFocusMessageId,
      showBackButton: false,
      key: ValueKey('pad-conv-${conversation.conversationType.index}-'
          '${conversation.target}-${conversation.line}-${toFocusMessageId ?? 0}'),
    );
  }

  /// 右栏的初始路由栈:占位页打底,窄栏形态下选中的会话叠在上面 ——
  /// 旋转成两栏时右栏直接接上,不用等一帧再补 push。
  List<Route<dynamic>> _initialPaneRoutes() {
    final selected = _shell.selectedConversation;
    _paneShowsConversation = selected != null;
    _selectedSeenInList = selected != null &&
        _conversationListViewModel.conversationList
            .any((info) => info.conversation == selected);
    return [
      _paneRoute(const _PadEmptyPane()),
      if (selected != null) _paneRoute(_conversationPane(selected, null)),
    ];
  }

  /// 系统返回键作用到右栏。弹回占位页(栈里只剩它)时顺手清掉选中态,
  /// 否则左栏还高亮着一个右栏已经不显示的会话,旋转到窄栏还会把它又推出来。
  void _popPane() {
    final navigator = _paneNavKey.currentState;
    if (navigator == null) {
      return;
    }
    navigator.maybePop().then((popped) {
      if (popped && !navigator.canPop()) {
        _shell.selectConversation(null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _claimOpeners();
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
              width: kPadListColumnWidth,
              child: HomeTabBar(key: widget.tabBarKey)),
          VerticalDivider(
              width: 0.5, thickness: 0.5, color: context.colors.hairline),
          Expanded(
            // 右栏是嵌套 Navigator,系统返回键默认只认根 Navigator ——
            // 不接这一层,在右栏里点开群资料后按返回会直接退出 App。
            // PC 端没有返回键,所以 PCHome 从来不需要这个。
            child: NavigatorPopHandler(
              onPopWithResult: (_) => _popPane(),
              child: Navigator(
                key: _paneNavKey,
                onGenerateRoute: (settings) =>
                    _paneRoute(const _PadEmptyPane(), settings),
                onGenerateInitialRoutes: (_, __) => _initialPaneRoutes(),
              ),
            ),
          ),
        ],
      ),
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
