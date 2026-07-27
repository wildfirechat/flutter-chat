import 'dart:async';

import 'package:dsbridge_flutter/dsbridge_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:chat/config.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/workspace/js_api.dart';
import 'package:chat/workspace/webview_background.dart';
import 'package:chat/workspace/webview_support.dart';
import 'package:chat/workspace/workspace_tab_bar.dart';
import 'package:chat/workspace/workspace_tabs_view_model.dart';
import 'package:chat/utils/media_url_redirector.dart';

/// 工作台。
///
/// 桌面端是多页签形态:头部一条页签栏,首页页签不可关闭,页内 `openUrl` 开新页签
/// 而不是压路由。移动端没有页签栏,页内跳转仍整页 push [WFWebViewScreen]。
///
/// 页签与 controller 都存在应用级的 [WorkspaceTabsViewModel] 里,本组件只是渲染层
/// —— 右栏每次切 tab 都会重建这条路由,状态放在这里会整页重载。
class WorkSpace extends StatefulWidget {
  const WorkSpace({super.key});

  @override
  State<WorkSpace> createState() => _WorkSpaceState();
}

class _WorkSpaceState extends State<WorkSpace> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isInlineWebViewSupported) {
      return;
    }
    // 工作台是远端 H5,明暗只能由宿主用 URL 上的 `?theme=` 告诉它(与 vue-pc-chat 一致)。
    // Theme.of 注册依赖,应用切明暗时会再次走到这里;工作台被切走期间换的主题,
    // 则在这里重新挂载时补上。首页 controller 还没建时什么都不做,首次加载由
    // controller 创建流程自己带上当前明暗。
    final brightness = Theme.of(context).brightness;
    final vm = context.read<WorkspaceTabsViewModel>();
    final controller = vm.homeTab.controller;
    final workspaceUrl = Config.workspaceUrl ?? '';
    if (controller == null ||
        workspaceUrl.isEmpty ||
        vm.homeLoadedBrightness == brightness) {
      return;
    }
    vm.homeLoadedBrightness = brightness;
    controller.loadRequest(workspaceUriWithTheme(
      MediaUrlRedirector.redirect(workspaceUrl),
      brightness,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!isInlineWebViewSupported) {
      return Scaffold(
        backgroundColor: context.colors.surface,
        body: SafeArea(
          child: WebViewUnsupportedView(url: Config.workspaceUrl ?? ''),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Consumer<WorkspaceTabsViewModel>(
          builder: (context, vm, _) {
            final tab = vm.activeTab;
            return Column(
              children: [
                if (isDesktopShell)
                  WorkspaceTabBar(
                    tabs: vm.tabs,
                    activeTabId: vm.activeTabId,
                    onSelect: vm.selectTab,
                    onClose: vm.closeTab,
                  )
                else
                  Container(
                    height: 18,
                    width: double.infinity,
                    color: context.colors.sectionGap,
                  ),
                Expanded(
                  // key 用页签 id:切页签时旧的 WebViewWidget 必须真的卸载。
                  // Linux 上原生窗口只在 paint 时同步位置,留在树上不画等于继续
                  // 显示在原地,几个网页会叠起来 —— 详见 WorkspaceTabsViewModel。
                  child: _WorkspaceTabView(
                    key: ValueKey(tab.id),
                    tab: tab,
                    hostContext: context,
                    brightness: Theme.of(context).brightness,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 单个页签的 WebView 宿主。只有当前页签会被挂上来。
class _WorkspaceTabView extends StatefulWidget {
  const _WorkspaceTabView({
    super.key,
    required this.tab,
    required this.hostContext,
    required this.brightness,
  });

  final WorkspaceTab tab;

  /// 交给 JsApi 用的 context。用工作台宿主的而不是本页签的:本页签在切走时会被
  /// 卸载,而后台页签里的 JS 定时器仍可能回调过来。
  final BuildContext hostContext;

  /// 首页页签首次加载时要拼进 URL 的明暗。
  final Brightness brightness;

  @override
  State<_WorkspaceTabView> createState() => _WorkspaceTabViewState();
}

class _WorkspaceTabViewState extends State<_WorkspaceTabView> {
  @override
  void initState() {
    super.initState();
    if (widget.tab.host == null) {
      _bindTabHost(
        widget.hostContext,
        widget.tab,
        widget.hostContext.read<WorkspaceTabsViewModel>(),
        widget.brightness,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.tab.controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return WebViewWidget(
      controller: controller,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
    );
  }
}

/// 给页签配上 WebView 宿主并开始加载:优先复用池子里的,没有才新建。
///
/// 放在 UI 侧而不是 ViewModel 里:JsApi 需要 BuildContext 做联系人选择等跳转,
/// 不该把 context 塞进 ViewModel。
void _bindTabHost(
  BuildContext hostContext,
  WorkspaceTab tab,
  WorkspaceTabsViewModel vm,
  Brightness brightness,
) {
  final WorkspaceWebViewHost? pooled = vm.takeIdleHost();
  if (pooled != null) {
    vm.attachHost(tab, pooled);
    // 换个页签用,JS 桥要改绑地址:getAuthCode 取的 host 和 chooseContacts 的
    // 前置检查都看它。导航回调不用重设 —— 闭包读的是 host.tab,不是具体页签。
    pooled.jsApi.rebind(tab.url);
    _loadTab(pooled.controller, tab, vm, brightness);
    return;
  }

  final bool isHome = !tab.closable;
  final DWebViewController controller = DWebViewController();
  if (isHome) {
    _clearInvalidWebViewCookies(controller);
  }

  unawaited(setTransparentBackground(controller));

  final host = WorkspaceWebViewHost(
    controller: controller,
    jsApi: JsApi(
      hostContext,
      tab.url,
      controller,
      // 桌面端页内跳转开新页签;移动端保持整页 push 的老形态。
      onOpenUrl: isDesktopShell ? (String url) => vm.openTab(url) : null,
      onClose: isDesktopShell ? vm.closeActiveTab : null,
    ),
  );
  vm.attachHost(tab, host);

  controller
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          debugPrint('WebView is loading (progress : $progress%)');
        },
        onPageStarted: (String url) {
          debugPrint('Page started loading: $url');
        },
        onPageFinished: (String url) async {
          debugPrint('Page finished loading: $url');
          // 页签标题跟随网页 title;首页页签固定显示"工作台",不必取。
          // 读 host.tab 而不是捕获 tab:宿主可能已经被复用到别的页签上了。
          final bound = host.tab;
          if (bound != null && bound.closable) {
            vm.updateTitle(bound.id, await controller.getTitle());
          }
        },
        // 应用页签沿用 WFWebViewScreen 的行为:页内跳走后 JsApi 的 _preCheck
        // 不再放行 chooseContacts。首页页签改造前就没有这一手,保持原样。
        onUrlChange: (UrlChange urlChange) {
          final url = urlChange.url;
          final bound = host.tab;
          if (url != null && bound != null && bound.closable) {
            host.jsApi.setCurrentUrl(url);
          }
        },
        onNavigationRequest: (NavigationRequest request) {
          if (request.url.startsWith('https://www.youtube.com/')) {
            debugPrint('blocking navigation to ${request.url}');
            return NavigationDecision.prevent;
          }
          debugPrint('allowing navigation to ${request.url}');
          return NavigationDecision.navigate;
        },
      ),
    )
    ..addJavaScriptObject(host.jsApi);

  _loadTab(controller, tab, vm, brightness);
}

void _loadTab(
  DWebViewController controller,
  WorkspaceTab tab,
  WorkspaceTabsViewModel vm,
  Brightness brightness,
) {
  final bool isHome = !tab.closable;
  // 首页地址在加载时才取 Config,与改造前一致 —— selectServer 将来接上双网判断后,
  // 不至于因为 ViewModel 在启动时缓存过一次而用上旧地址。
  final String rawUrl = isHome ? (Config.workspaceUrl ?? '') : tab.url;
  if (rawUrl.isEmpty) {
    return;
  }
  final String url = MediaUrlRedirector.redirect(rawUrl);
  if (isHome) {
    vm.homeLoadedBrightness = brightness;
    controller.loadRequest(workspaceUriWithTheme(url, brightness));
  } else {
    controller.loadRequest(Uri.parse(url));
  }
}

void _clearInvalidWebViewCookies(DWebViewController controller) async {
  var sp = await SharedPreferences.getInstance();
  var webViewUserId = sp.getString('webview-userId');
  if (webViewUserId == null) {
    sp.setString('webview-userId', Imclient.currentUserId);
    return;
  } else if (webViewUserId == Imclient.currentUserId) {
    return;
  }
  controller.clearCache();
  controller.clearLocalStorage();
}

Uri workspaceUriWithTheme(String urlString, Brightness brightness) {
  final uri = Uri.parse(urlString);
  final themeValue = brightness == Brightness.dark ? 'dark' : 'light';
  final queryParams = Map<String, String>.from(uri.queryParameters);
  queryParams['theme'] = themeValue;
  return uri.replace(queryParameters: queryParams);
}
