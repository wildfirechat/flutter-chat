import 'package:dsbridge_flutter/dsbridge_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'package:chat/config.dart';
import 'package:chat/workspace/webview_support.dart';

/// 工作台里的一个页签。
///
/// [controller] 由 UI 侧在该页签第一次挂载时创建(见 work_space.dart 的
/// `_createTabController`),ViewModel 只负责持有与释放 —— 创建 controller 需要
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

  DWebViewController? controller;
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

  /// 同时存活的页签上限。每个 WebKitWebView 在 Linux 上是一个独立的 web 进程
  /// (约 100~200MB),国产 ARM 机器上开太多会吃光内存,故开新页签时挤掉最旧的。
  static const int maxTabCount = 6;

  final List<WorkspaceTab> _tabs = [];
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
      final victim = _tabs.firstWhere((tab) => tab.closable, orElse: () => homeTab);
      if (victim.closable) {
        _tabs.remove(victim);
        _releaseController(victim);
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
    _releaseController(tab);
    if (_activeTabId == tab.id) {
      // 关掉当前页签后落到它左边那个,与浏览器一致。
      _activeTabId = _tabs[index - 1 < 0 ? 0 : index - 1].id;
    }
    notifyListeners();
  }

  /// 关闭当前页签(JS 侧调 `close` 时走这里)。首页不可关,直接忽略。
  void closeActiveTab() => closeTab(_activeTabId);

  /// controller 创建后登记进来。**不 notifyListeners**:调用点在页签 widget 的
  /// initState 里,此时重建整棵树既无必要也会触发 setState during build。
  void attachController(String id, DWebViewController controller) {
    for (final tab in _tabs) {
      if (tab.id == id) {
        tab.controller = controller;
        return;
      }
    }
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

  @override
  void dispose() {
    for (final tab in _tabs) {
      _releaseController(tab, immediate: true);
    }
    _tabs.clear();
    super.dispose();
  }

  void _releaseController(WorkspaceTab tab, {bool immediate = false}) {
    final controller = tab.controller;
    tab.controller = null;
    if (controller == null) {
      return;
    }
    if (immediate) {
      // 整个 ViewModel 在销毁,后面不一定还有帧,只能就地释放。
      disposeWebViewController(controller);
      return;
    }
    // 关页签要等这一帧结束再释放:紧接着的 notifyListeners 会重建工作台,把这个
    // 页签的 WebViewWidget 卸载,而插件在卸载时还要往 controller 推一次
    // setFrame(Rect.zero) 去藏掉原生窗口。先 dispose 的话那一下会抛
    // StateError(controller already disposed),变成一条没人接的 Future 错误。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      disposeWebViewController(controller);
    });
  }
}
