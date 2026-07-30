import 'package:dsbridge_flutter/dsbridge_flutter.dart';
import 'package:flutter/foundation.dart';

import 'package:chat/config.dart';
import 'package:chat/workspace/js_api.dart';

/// 一个可复用的 WebView 宿主:controller + 它的 JS 桥。
///
/// **为什么要复用而不是用完就销毁**:webview_flutter 的公开 API 里
/// `WebViewController` 根本没有 dispose,桌面两端都够不着真正的释放:
///
/// - Linux(webview_all_linux 1.2.1):平台 controller 上倒是有 `dispose()`,但它的
///   原生实现只做 `gtk_widget_hide`,WebView 一直留在插件的哈希表里活到进程退出
///   —— 每个 `WebKitWebView` 背后是一个常驻的 `WebKitWebProcess`(约 100~200MB)。
///   试过打补丁让它走真正的销毁流程,结果 `gtk_widget_destroy` 会让插件把 FlView
///   的输入区域算成空的,整个顶层窗口对鼠标透明(点击穿透到后面的应用、窗口也
///   拖不动,而拖不动就再触发不了重算,等于死锁)。
/// - Windows(webview_all_windows 1.2.1):底层 `WebviewController.dispose()` 是真
///   销毁,但它是私有的,平台 controller 没往外暴露。
///
/// 所以关页签时不销毁,而是把宿主收回池子:先 load 空白页放掉页面内存,下次开
/// 页签直接复用。WebView 数量因此封顶在"同时打开过的最大页签数",不会随开关
/// 次数增长。
class WorkspaceWebViewHost {
  WorkspaceWebViewHost({required this.controller, required this.jsApi});

  final DWebViewController controller;
  final JsApi jsApi;

  /// 当前绑定的页签。回收进池子时置空。
  ///
  /// controller 的导航回调是在创建时一次性注册的,闭包里只能引用这个可变字段,
  /// 不能捕获具体的 [WorkspaceTab] —— 否则复用后标题会回填到已关闭的页签上。
  WorkspaceTab? tab;

  /// 有全屏内容(联系人选择、内嵌网页跳转等)盖住这个页签时置 true。
  ///
  /// 挂在 host 而不是 [WorkspaceTab] 上:[JsApi.pushOverlay] 的回调在 host 首次
  /// 创建时就绑死了(见 work_space.dart 的 `_bindTabHost`),页签回收复用时不会
  /// 重新构造 JsApi,回调里只能安全引用不随页签变化的对象。
  bool hideForOverlay = false;
}

/// 工作台里的一个页签。
///
/// [host] 由 UI 侧在该页签第一次挂载时创建或从池子里取(见 work_space.dart 的
/// `_bindTabHost`),ViewModel 只负责持有与回收 —— 创建 controller 需要
/// BuildContext(JsApi 要用它做 Navigator 跳转),不该让 ViewModel 碰。
class WorkspaceTab {
  WorkspaceTab({
    required this.id,
    required this.url,
    required this.closable,
    this.title,
  });

  final String id;

  /// 页签的初始地址。页内跳转不改这个值,只用于去重与重新加载。
  final String url;

  /// 首页页签不可关闭。
  final bool closable;

  /// 网页 title,加载完成后由 onPageFinished 回填。
  String? title;

  WorkspaceWebViewHost? host;

  DWebViewController? get controller => host?.controller;
}

/// 工作台的多页签状态。
///
/// **为什么必须活在路由之外**:右栏每次 `_openPage` 都是一条新路由(见
/// pc_home.dart 的 `_paneRoute`),页面 State 必然重建。只有把 controller 攥在
/// 应用级 ViewModel 里,切走再切回工作台才不会整页重新加载。
///
/// **为什么后台页签不留在 widget 树里**:Linux 的 WebView 是挂在 GtkOverlay 上的
/// 原生窗口,位置只在 Flutter `paint()` 时推送给原生侧(webview_all_linux 的
/// `_LinuxGeometryRenderBox`)。不 paint 就收不到任何通知,原生窗口会停在原地
/// 继续显示 —— 所以 IndexedStack / Offstage / Visibility 这类"留在树上但不画"的
/// 方案会让几个网页在屏幕上叠成一摞。正确做法是只挂当前页签的 WebViewWidget:
/// 卸载时 `detach()` 会推 `setFrame(Rect.zero, visible:false)` 把原生窗口藏掉,
/// 重新挂载时第一帧 paint 自动恢复。网页状态不丢,因为原生 WebView 属于
/// controller 而不属于 widget。
class WorkspaceTabsViewModel extends ChangeNotifier {
  WorkspaceTabsViewModel() {
    _tabs.add(WorkspaceTab(
      id: homeTabId,
      url: Config.workspaceUrl ?? '',
      closable: false,
    ));
    _activeTabId = homeTabId;
  }

  static const String homeTabId = 'workspace-home';

  /// 同时存活的页签上限。每个 WebView 在 Linux 上是一个独立的 web 进程,
  /// 且**销毁不掉只能复用**(见 [WorkspaceWebViewHost]),所以这个上限同时也是
  /// 整个进程里 WebView 数量的上限。开新页签时挤掉最旧的。
  static const int maxTabCount = 6;

  final List<WorkspaceTab> _tabs = [];

  /// 关掉页签后回收下来的空闲宿主,开新页签时优先复用。
  final List<WorkspaceWebViewHost> _idleHosts = [];

  String _activeTabId = homeTabId;
  int _seq = 0;

  /// 首页页签当前是按哪个明暗加载的(远端 H5 只能靠 URL 上的 `?theme=` 知道宿主主题)。
  ///
  /// 存在这里而不是页面 State 里:工作台被切走期间应用可能换了主题,而 controller
  /// 是活着的 —— 再回来时页面 State 是全新的,只有 ViewModel 记得上次用的是什么。
  Brightness? homeLoadedBrightness;

  List<WorkspaceTab> get tabs => List.unmodifiable(_tabs);

  String get activeTabId => _activeTabId;

  WorkspaceTab get homeTab => _tabs.first;

  WorkspaceTab get activeTab =>
      _tabs.firstWhere((tab) => tab.id == _activeTabId, orElse: () => homeTab);

  /// 打开一个页签。同一地址已开着就直接切过去,不重复开。
  void openTab(String url, {String? title}) {
    for (final tab in _tabs) {
      if (tab.url == url) {
        selectTab(tab.id);
        return;
      }
    }

    if (_tabs.length >= maxTabCount) {
      // 首页永远不挤,从最旧的可关闭页签开始腾位置。
      final victim =
          _tabs.firstWhere((tab) => tab.closable, orElse: () => homeTab);
      if (victim.closable) {
        _tabs.remove(victim);
        _recycleHost(victim);
      }
    }

    final tab = WorkspaceTab(
      id: 'workspace-tab-${_seq++}',
      url: url,
      closable: true,
      title: title,
    );
    _tabs.add(tab);
    _activeTabId = tab.id;
    notifyListeners();
  }

  /// 给 [host] 标一下是否被全屏内容盖住,驱动 UI 挂/卸它的 [WebViewWidget]。
  ///
  /// 必须传具体的 host 而不是查"当前页签"——后台页签的 JS 定时器可能在页签切走
  /// 之后仍然回调进来触发 [JsApi.pushOverlay],这时 host 早已不是 activeTab 的了。
  /// 见 [JsApi.pushOverlay]。
  void setHostOverlayHidden(WorkspaceWebViewHost host, bool hidden) {
    if (host.hideForOverlay == hidden) {
      return;
    }
    host.hideForOverlay = hidden;
    notifyListeners();
  }

  void selectTab(String id) {
    if (_activeTabId == id) {
      return;
    }
    _activeTabId = id;
    notifyListeners();
  }

  void closeTab(String id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0 || !_tabs[index].closable) {
      return;
    }
    final tab = _tabs.removeAt(index);
    _recycleHost(tab);
    if (_activeTabId == tab.id) {
      // 关掉当前页签后落到它左边那个,与浏览器一致。
      _activeTabId = _tabs[index - 1 < 0 ? 0 : index - 1].id;
    }
    notifyListeners();
  }

  /// 关闭当前页签(JS 侧调 `close` 时走这里)。首页不可关,直接忽略。
  void closeActiveTab() => closeTab(_activeTabId);

  /// 取一个空闲宿主复用,没有则返回 null(调用方新建)。
  WorkspaceWebViewHost? takeIdleHost() =>
      _idleHosts.isEmpty ? null : _idleHosts.removeLast();

  /// 宿主与页签互相绑定。**不 notifyListeners**:调用点在页签 widget 的
  /// initState 里,此时重建整棵树既无必要也会触发 setState during build。
  void attachHost(WorkspaceTab tab, WorkspaceWebViewHost host) {
    tab.host = host;
    host.tab = tab;
  }

  void updateTitle(String id, String? title) {
    for (final tab in _tabs) {
      if (tab.id == id && tab.title != title) {
        tab.title = title;
        notifyListeners();
        return;
      }
    }
  }

  /// 把页签的 WebView 解绑并收回池子。
  ///
  /// 不销毁 —— 原因见 [WorkspaceWebViewHost]。先 load 空白页,把网页占的内存还给
  /// 系统(web 进程本身还在,但只剩空白页的开销)。
  void _recycleHost(WorkspaceTab tab) {
    final host = tab.host;
    tab.host = null;
    if (host == null) {
      return;
    }
    host.tab = null;
    host.controller.loadRequest(Uri.parse('about:blank'));
    _idleHosts.add(host);
  }
}
