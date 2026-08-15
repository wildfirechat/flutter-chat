import 'package:flutter/material.dart';
import 'package:imclient/imclient_platform.dart';
import 'package:provider/provider.dart';

import 'package:chat/app_navigator.dart';
import 'package:chat/app_shell.dart';
import 'package:chat/home/home.dart';
import 'package:chat/pad/pad_home.dart';
import 'package:chat/pc/pc_home.dart';
import 'package:chat/pc/pc_shell_view_model.dart';

/// 登录后的主界面入口,按形态分流到三种 Shell:
///
/// | | 走哪个 |
/// |---|---|
/// | 手机 | [HomeTabBar] 单栏 |
/// | PC | [PCHome] 三栏 |
/// | 平板 | 宽度 ≥ 断点走 [PadHome] 两栏,否则回落 [HomeTabBar] |
///
/// **必须放在 MaterialApp 之下**(即作为 `home:`,而不是在 MyApp.build 里就地
/// 三元):形态判断要读 MediaQuery,放在 MaterialApp 之上会让整个 MaterialApp
/// 跟着窗口尺寸重建,根 Navigator 的路由栈会被连累。
///
/// 平板旋转/分屏会在两种 Shell 之间来回切,详情的上下文由 [PCShellViewModel]
/// 里的选中会话承载,见 [_handleBreakpointCrossed]。
class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  bool? _wasMultiPane;

  /// 左栏/单栏那个 [HomeTabBar] 的身份。
  ///
  /// 平板跨断点时 HomeTabBar 会从「AppHome 的直接子节点」搬到「PadHome 左栏里」
  /// (或反过来)。挂同一个 GlobalKey,Flutter 会把整棵子树连同 State 一起搬过去,
  /// 选中的 tab 与列表滚动位置都不丢 —— 否则转一下屏就跳回消息 tab、滚回顶部。
  ///
  /// 只有平板需要:手机和 PC 不存在这种搬移,给 null 保持原来的 const 构造。
  final GlobalKey _tabBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 本 Widget 的生命周期就是"一次登录会话":登录成功时才被建出来,登出时随
    // home 一起销毁。Shell 是应用级的(跨登录复用),在这里清干净,免得换账号后
    // 右栏还挂着上个账号的会话。PCHome 自己也 reset,重复一次无副作用。
    _shellOrNull()?.reset();
  }

  PCShellViewModel? _shellOrNull() {
    try {
      return Provider.of<PCShellViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      return null; // 手机端不注册 Shell
    }
  }

  /// 断点跨越时把"当前正在看的会话"在两种形态之间搬过去。
  ///
  /// 只处理会话这一种页面:其余整页(设置、资料…)在窄栏下是普通路由,旋转时
  /// 保持原样 —— 否则转一下屏就把用户正看的页面弹掉了。
  void _handleBreakpointCrossed(bool multiPane) {
    final shell = _shellOrNull();
    if (shell == null) {
      return;
    }
    final navigator = Navigator.of(context);
    if (multiPane) {
      // 窄 → 宽:窄栏下会话是压在根栈上的整页,收起它,让右栏接手显示。
      // 从栈顶连着弹掉会话页(连点几个会话会叠好几层),遇到第一个非会话页就停 ——
      // 设置、资料这类页面不该因为转了下屏就被弹掉。
      navigator
          .popUntil((route) => route.settings.name != kConversationRouteName);
      return;
    }
    // 宽 → 窄:右栏没了,把选中的会话补成整页,不然旋转一下聊天就没了。
    final conversation = shell.selectedConversation;
    if (conversation != null) {
      pushConversationRoute(context, conversation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool multiPane = AppShell.isMultiPane(context);
    if (_wasMultiPane != null && _wasMultiPane != multiPane) {
      // 形态切换要等这一帧的新 Shell 挂上去之后再搬会话:此刻旧 Shell 还在树上,
      // 立即 push/pop 会作用在正要被替换的那棵子树上。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleBreakpointCrossed(multiPane);
        }
      });
    }
    _wasMultiPane = multiPane;

    if (!multiPane) {
      return WfcPlatform.isTablet
          ? HomeTabBar(key: _tabBarKey)
          : const HomeTabBar();
    }
    return WfcPlatform.isDesktop
        ? const PCHome()
        : PadHome(tabBarKey: _tabBarKey);
  }
}
