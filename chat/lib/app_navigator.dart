import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/login_screen.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/pc_qr_login_screen.dart';
import 'package:chat/pc/pc_shell_view_model.dart';

/// 平台兼容导航的唯一入口。
/// 桌面 Shell 内(能取到 [PCShellViewModel])会话/页面在右栏打开并同步选中态,
/// 移动端整页 push。共享页面一律经由这里跳转,不要自行判断平台或下钻回调。

PCShellViewModel? _shellOf(BuildContext context) {
  if (!isDesktopShell) {
    return null;
  }
  try {
    return Provider.of<PCShellViewModel>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}

/// 打开会话:桌面右栏打开并选中会话列表对应项,移动端 push [ConversationScreen]。
void openConversation(BuildContext context, Conversation conversation,
    {int? toFocusMessageId}) {
  final shell = _shellOf(context);
  if (shell != null) {
    shell.openConversation(conversation, toFocusMessageId: toFocusMessageId);
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ConversationScreen(conversation,
              toFocusMessageId: toFocusMessageId)),
    );
  }
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
      builder: (_) =>
          isDesktopShell ? const PCQRLoginScreen() : const LoginScreen(),
      settings: const RouteSettings(name: 'login'),
    ),
    (route) => false,
  );
}
