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

/// 打开页面:从**栏外**调用是右栏整栏替换展示(其上的侧抽屉等浮层路由会一并清掉),
/// 从**右栏内部**调用则是在右栏那条栈上正常 push,移动端 push。
///
/// 返回的 Future 只在会 push 的那两种情况下有意义(页面被弹回时完成)。整栏替换时
/// 右栏是"换内容"而不是"开一层",没有"关闭"这个时刻,立即完成 —— 靠 `.then()` 做
/// 收尾的调用点要另想办法(通常是让页面自己在动作完成时通知对应的 ViewModel)。
Future<void> openPage(BuildContext context, Widget page) {
  final shell = _shellOf(context);
  if (shell != null && !_inPadPane(context)) {
    shell.openPage(page);
    return Future<void>.value();
  }
  return Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

/// 调用点是不是在**平板右栏**那条嵌套栈里。
///
/// 平板右栏一条栈上要同时装下两种语义:左栏选中另一项是"换内容"(整栏替换),
/// 而栏内页面自己往下钻是"开一层"(群资料 → 成员资料,返回要回得去)。两者都走
/// [openPage],只能按调用点在栈里还是栈外分:嵌套栈里的页面,其最近的 Navigator
/// 不是根 Navigator。
///
/// **只认平板**:PC 右栏是带页面缓存的"整栏替换"形态(见 PCHome._openPage),
/// 栏内调用 openPage 换掉整栏是它要的行为(pc_settings_page 里就明写着靠这个),
/// 不能跟着改。手机没有右栏,压根到不了这里。
bool _inPadPane(BuildContext context) {
  if (!_isPadShell(context)) {
    return false;
  }
  final nearest = Navigator.maybeOf(context);
  return nearest != null &&
      nearest != Navigator.maybeOf(context, rootNavigator: true);
}

/// 压一条**盖住整个窗口**的路由:媒体预览、扫码这类全屏体验。
///
/// 平板两栏时右栏只是窗口的一部分,压在右栏那条嵌套栈上只能盖住右半边 ——
/// 而且预览的进出场动画是按气泡的**全局**坐标算的,压错栈连动画起点都是偏的。
/// 手机上根 Navigator 就是唯一那个,与直接 `Navigator.push` 完全一致。
Future<T?> pushFullScreen<T>(BuildContext context, Route<T> route) {
  return Navigator.of(context, rootNavigator: true).push(route);
}

/// 选完人/建完群之后进入会话:替换掉当前这一页,返回时跳过选择页。
///
/// 与 [openConversation] 的区别只在单栏:那边是 push(选择页留在栈里),
/// 这边是 pushReplacement。多栏下两者一样 —— 右栏整栏换成会话,
/// 顺带把左栏列表的选中态也同步上。
void replaceWithConversation(BuildContext context, Conversation conversation) {
  final shell = _shellOf(context);
  if (shell != null) {
    shell.openConversation(conversation);
    return;
  }
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: kConversationRouteName),
      builder: (_) => ConversationScreen(conversation),
    ),
  );
}

/// 打开 [showSearch] 那套搜索页:多栏形态压进右栏,单栏仍是整页。
///
/// 不能走 [openPage] —— SearchDelegate 的界面是一条自带动画与状态的路由,
/// 只能由 showSearch 自己压。所以这里换的是"压给哪个 Navigator":
/// 取右栏 Navigator 的 overlay context,它的最近 Navigator 祖先正是右栏那个。
Future<T?> openSearch<T>(BuildContext context, SearchDelegate<T> delegate) {
  final paneContext =
      _shellOf(context)?.paneNavigatorProvider?.call()?.overlay?.context;
  return showSearch<T>(context: paneContext ?? context, delegate: delegate);
}

/// 关闭右栏当前页面,回到占位欢迎页(页面内容已失效时用,如群聊被移出通讯录)。
/// 仅桌面 Shell 有效;移动端无对应形态,为 no-op,调用方自行决定是否 pop。
void closePage(BuildContext context) {
  _shellOf(context)?.closePage();
}

/// 在当前导航栈中 push 一个子页面（保留返回历史）。
///
/// 平板走移动端那条(带转场):右栏是触摸交互、移动端密度,栏内往下钻就该像手机上
/// 那样滑进来 —— 会话页点右上角进群资料本来就是这个样子(它直接 Navigator.push),
/// 这里不跟上就会同一栏里一半有转场一半没有。
void pushPage(BuildContext context, Widget page) {
  if (_shellOf(context) != null && !_isPadShell(context)) {
    // PC:在右栏 Navigator 中正常 push (无转场动画，符合 PC 体验)
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
  if (_shellOf(context) != null && !_isPadShell(context)) {
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

bool _isPadShell(BuildContext context) =>
    AppShell.shellFor(context) == AppShellKind.padTwoPane;

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
