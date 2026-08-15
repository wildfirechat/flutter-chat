import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/login_screen.dart';
import 'package:chat/pc/pc_qr_login_screen.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/app_shell.dart';

/// 平台兼容导航的唯一入口。
/// 桌面 Shell 内(能取到 [PCShellViewModel])会话/页面在右栏打开并同步选中态,
/// 移动端整页 push。共享页面一律经由这里跳转,不要自行判断平台或下钻回调。

/// 单栏形态下会话整页的路由名。平板在窄↔宽之间旋转时,[AppHome] 靠它认出
/// "栈顶这一页是会话",从而把它收起来交给右栏,而不误伤其它页面。
const String kConversationRouteName = 'conversation';

/// 注册了 Shell 就返回它,与当前是不是多栏无关。
/// 平板窄栏时 Shell 仍在(只是不往右栏开),选中态要照记 —— 旋转成两栏时靠它续上。
PCShellViewModel? _registeredShellOf(BuildContext context) {
  try {
    return Provider.of<PCShellViewModel>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}

PCShellViewModel? _shellOf(BuildContext context) {
  if (!AppShell.isMultiPane(context)) {
    return null;
  }
  return _registeredShellOf(context);
}

/// 打开会话:多栏形态在右栏打开并选中会话列表对应项,单栏整页 push [ConversationScreen]。
void openConversation(BuildContext context, Conversation conversation,
    {int? toFocusMessageId}) {
  final shell = _shellOf(context);
  if (shell != null) {
    shell.openConversation(conversation, toFocusMessageId: toFocusMessageId);
  } else {
    pushConversationRoute(context, conversation,
        toFocusMessageId: toFocusMessageId);
  }
}

/// 单栏形态下把会话作为整页压上根导航栈。
///
/// 平板上同时把选中态记进 Shell:旋转成两栏时右栏据此接着显示。整页被弹回时
/// **不**清选中态 —— 与 PC 右栏一致(退出会话后右栏仍停在最后看过的那个),
/// 而且清了会与旋转时的程序化 pop 打架。手机端取不到 Shell,这一步是 no-op,
/// 行为与直接 `Navigator.push` 完全一致。
void pushConversationRoute(BuildContext context, Conversation conversation,
    {int? toFocusMessageId}) {
  _registeredShellOf(context)?.selectConversation(conversation);
  Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: kConversationRouteName),
      builder: (_) =>
          ConversationScreen(conversation, toFocusMessageId: toFocusMessageId),
    ),
  );
}

/// 打开页面:桌面右栏整栏替换展示(其上的侧抽屉等浮层路由会一并清掉),移动端 push。
void openPage(BuildContext context, Widget page) {
  final shell = _shellOf(context);
  if (shell != null) {
    shell.openPage(page);
  } else {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

/// 关闭右栏当前页面,回到占位欢迎页(页面内容已失效时用,如群聊被移出通讯录)。
/// 仅桌面 Shell 有效;移动端无对应形态,为 no-op,调用方自行决定是否 pop。
void closePage(BuildContext context) {
  _shellOf(context)?.closePage();
}

/// 在当前导航栈中 push 一个子页面（保留返回历史）。
void pushPage(BuildContext context, Widget page) {
  final shell = _shellOf(context);
  if (shell != null) {
    // 桌面端，在右栏 Navigator 中正常 push (无转场动画，符合 PC 体验)
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  } else {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

/// 替换当前页(如"选择会话/用户"页选完后进入结果页,返回时跳过选择页)。
void pushReplacementPage(BuildContext context, Widget page) {
  final shell = _shellOf(context);
  if (shell != null) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  } else {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }
}

/// 回到登录页(登出/被踢/token 失效):若栈顶已是登录页则不动,
/// 否则清空根导航栈换成平台各自的登录页。调用方自行负责 [Imclient.disconnect]。
void navigateToLogin(NavigatorState rootNavigator) {
  bool topIsLogin = false;
  rootNavigator.popUntil((route) {
    topIsLogin = route.settings.name == 'login';
    return true;
  });
  if (topIsLogin) {
    return;
  }
  rootNavigator.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => AppShell.isDesktopStyle
          ? const PCQRLoginScreen()
          : const LoginScreen(),
      settings: const RouteSettings(name: 'login'),
    ),
    (route) => false,
  );
}
