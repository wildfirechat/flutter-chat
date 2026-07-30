import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imclient/imclient_method_channel.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:window_manager/window_manager.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shortcuts/ambient_shortcuts.dart';
import '../../viewmodel/font_size_view_model.dart';
import '../../viewmodel/locale_view_model.dart';
import '../../viewmodel/theme_view_model.dart';
import '../../widget/watermark_overlay.dart';
import 'shared_imclient_channel.dart';
import 'window_event_channel.dart';

/// PC 子窗口 App 的公共基类(call/media_preview/moment/search 四个窗口
/// 的 App State 逐字重复的样板收敛于此)。
///
/// 用法:
/// ```dart
/// class _FooWindowAppState extends State<FooWindowApp>
///     with WindowListener, SubWindowAppBase<FooWindowApp> { ... }
/// ```
/// 注意 [WindowListener] 必须列在本 mixin 之前:它提供各窗口事件的默认空
/// 实现(满足 `implements WindowListener`),本 mixin 只覆盖 [onWindowClose]。
///
/// 基类统一实现的流程:
/// - init:创建 Theme/FontSize/Locale 三个偏好 VM → 解析 arguments 的
///   `_selfUserId` 设 [ImclientPlatform] userId → 替换 [imclientChannel]
///   (若提供)→ [registerMessageContents] → 经 [WindowEventChannel] 注册
///   [eventHandlers] + listen → [onWindowReady](子类解析参数等)→ 发
///   `<kind>.ready` 通知(带 windowId)→ setState(isReady) →
///   postFrame + 1s 兜底 [_postFirstFrameInit](幂等守卫)。
/// - window_manager:50ms 延迟 → ensureInitialized → `_windowManagerInited`
///   门闩 → addListener(this) → waitUntilReadyToShow → [useNormalTitleBar]
///   时恢复标准标题栏 → 更新标题(门闩保护,解决偏好加载与 window_manager
///   初始化并发导致的 macOS 原生崩溃)→ setMinimumSize → show → focus。
/// - 偏好加载完成后按最终语言再走一次标题更新(同样走门闩)。
/// - 关窗:[onWindowClose] 通知主窗口 `<kind>.windowClosed`。
/// - build:MultiProvider(三个偏好 VM)+ Consumer(Locale+FontSize)+
///   MaterialApp(主题/字号/语言与主窗口同源);未 ready 时统一显示
///   CircularProgressIndicator,ready 后交给 [buildHome]。
mixin SubWindowAppBase<T extends StatefulWidget> on State<T>
    implements WindowListener {
  // -------------------------------------------------------------- 子类钩子

  /// 子窗口标识,兼作事件名前缀(`<kind>.ready` / `<kind>.windowClosed`)。
  String get windowKind;

  /// 窗口标题。l10n 由基类按 basicLocaleListResolution +
  /// lookupAppLocalizations 解析(子窗口没有挂在 MaterialApp 下的 context)。
  String windowTitle(AppLocalizations l10n);

  /// 窗口最小尺寸。
  Size get minWindowSize;

  /// ready 之后的主内容。
  Widget buildHome(BuildContext context);

  /// 子窗口的 IM 代理通道。
  ///
  /// 默认所有子窗口都装同一套 [SharedImclientChannel](主窗口侧对应
  /// MainImclientProxy),能力完全一致,新增窗口零成本。子类不需要覆写——
  /// 此前每个窗口一份 channel 子类,同一个方法有四份实现,已造成三次静默故障
  /// (见 [SharedImclientChannel] 类注释)。
  late final SharedImclientChannel imclientChannel = SharedImclientChannel(
    windowId: windowId,
    windowName: windowKind,
  );

  /// 注册消息内容类型(仅 Dart 层解码用);默认无。
  void registerMessageContents() {}

  /// 主窗口转发事件的 handler 表;默认空。
  Map<String, Future<dynamic> Function(dynamic)> get eventHandlers => const {};

  /// 子类初始化(解析 arguments 等),在 ready 通知发出前 await 完成。
  Future<void> onWindowReady() async {}

  /// 是否恢复标准标题栏(desktop_multi_window 创建的 macOS 子窗口默认
  /// 隐藏标题栏)。搜索窗为 true,其余默认 false。
  bool get useNormalTitleBar => false;

  /// Ctrl/Cmd+W 是否关闭本窗口;默认 true。通话窗口没有独立的"关闭"语义
  /// (只能挂断结束通话),覆写为 false 避免快捷键误触发关窗。
  bool get closableByShortcut => true;

  /// Ctrl/Cmd+W 触发的关闭动作。默认走 desktop_multi_window 自己的通道
  /// 关闭窗口并通知主窗口;不能用 windowManager.close():若
  /// ensureInitialized 尚未执行,macOS 侧会因 _mainWindow 为 nil 强解包
  /// 直接崩溃进程。关闭前有额外收尾工作(如媒体预览窗要先暂停视频)的
  /// 子类覆写本方法。
  Future<void> requestClose() async {
    await WindowEventChannel.invoke(0, '$windowKind.windowClosed', {
      'windowId': windowId,
    });
    try {
      await WindowController.fromWindowId(windowId).close();
    } catch (e) {
      debugPrint('$_tag close window failed: $e');
    }
  }

  /// 通知主窗口子窗口已就绪。默认发 `<kind>.ready`(带 windowId);
  /// 通话窗口覆写为 voipStatusChanged {status:'ready'}。
  /// 实现若不 await 内部 invoke,即为 fire-and-forget。
  Future<void> notifyReady() async {
    await WindowEventChannel.invoke(0, '$windowKind.ready', {
      'windowId': windowId,
    });
  }

  /// 窗口样式,在 window_manager ensureInitialized + waitUntilReadyToShow
  /// 之后由基类调用。默认实现:按需恢复标准标题栏 → 更新标题 →
  /// setMinimumSize → show → focus;通话窗口覆写为自己的样式分支。
  Future<void> applyWindowStyle() async {
    if (useNormalTitleBar) {
      // desktop_multi_window 创建的 macOS 子窗口默认隐藏标题栏
      // (fullSizeContentView + titleVisibility=.hidden),恢复为标准标题栏。
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    }
    await _updateWindowTitle();
    await windowManager.setMinimumSize(minWindowSize);
    await windowManager.show();
    await windowManager.focus();
  }

  /// 子窗口额外的 providers(挂在三个偏好 VM 之后);默认无。
  List<SingleChildWidget> get extraProviders => [];

  /// MaterialApp 的 navigatorKey(如媒体预览窗的 toast Overlay 依附);默认无。
  GlobalKey<NavigatorState>? get navigatorKey => null;

  /// 亮/暗主题与 themeMode。默认与主窗口同源(AppTheme);强制暗色的
  /// 窗口(通话、媒体预览)覆写。
  ThemeData buildLightTheme() => AppTheme.light();
  ThemeData buildDarkTheme() => AppTheme.dark();
  ThemeMode get themeMode => themeViewModel.themeMode;

  /// 未 ready 时的加载页;默认居中 CircularProgressIndicator。
  Widget buildLoading(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  /// 子窗口 Widget 持有的窗口 id / 创建参数。
  int get windowId;
  Map<String, dynamic> get windowArguments;

  // -------------------------------------------------------------- 基类状态

  late final FontSizeViewModel fontSizeViewModel;
  late final ThemeViewModel themeViewModel;
  late final LocaleViewModel localeViewModel;

  bool _isReady = false;

  /// window_manager 是否已完成 ensureInitialized。子窗口里任何
  /// windowManager 调用都必须排在其后,否则 macOS 原生侧
  /// WindowManager.mainWindow 还是 nil,强解包直接崩溃(Swift fatal
  /// error 无法被 Dart try/catch 捕获)。
  bool _windowManagerInited = false;

  /// 子类在调用任何 windowManager 方法前必须先看这个门闩(同上)。
  @protected
  bool get windowManagerReady => _windowManagerInited;

  bool _postFirstFrameInitDone = false;

  AmbientShortcutRegistration? _closeShortcut;

  String get _tag => windowKind;

  // -------------------------------------------------------------- init 流程

  @override
  void initState() {
    super.initState();
    fontSizeViewModel = FontSizeViewModel(autoLoad: false);
    themeViewModel = ThemeViewModel();
    localeViewModel = LocaleViewModel(autoLoad: false);
    if (closableByShortcut) {
      // 登记为环境快捷键而不是包一层 Focus:焦点在谁手里都能关窗,
      // 内容区也不必再为了收按键去和祖先抢焦点(详见 ambient_shortcuts.dart)
      _closeShortcut = AmbientShortcuts.instance.register(
        bindings: {
          const CmdOrCtrl(LogicalKeyboardKey.keyW): () {
            requestClose();
            return true;
          },
        },
        isActive: () => mounted,
        debugLabel: '$windowKind window',
      );
    }
    _init();
  }

  @override
  void dispose() {
    _closeShortcut?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      debugPrint('$_tag _init start, windowId=$windowId');

      // 子窗口 isolate 中 Imclient 没有自己连接 IM,先设置当前用户。
      // 创建参数携带 _selfUserId 时设置(四类子窗口均注入,媒体预览窗
      // 虽不连 IM,也用它来显示全局水印)。
      final selfUserId = windowArguments['_selfUserId'] as String?;
      if (selfUserId != null) {
        ImclientPlatform.instance.userId = selfUserId;
      }

      // 1. 替换 IM 通道为共享代理通道(所有子窗口一致)。
      ImclientPlatform.instance.channel = imclientChannel;

      // 2. 注册消息内容类型(仅 Dart 层解码用)。
      registerMessageContents();

      // 3. 监听主窗口转发来的事件:共享通道自己的 handler(如
      //    sendMessage 结果回传)先注册,再叠加子类的窗口专有 handler。
      final eventChannel = WindowEventChannel();
      imclientChannel.eventHandlers.forEach(eventChannel.register);
      eventHandlers.forEach(eventChannel.register);
      eventChannel.listen();

      // 4. 子类初始化(解析 arguments 等),完成后才通知主窗口就绪。
      await onWindowReady();

      // 5. 通知主窗口已就绪。
      await notifyReady();

      setState(() => _isReady = true);

      // window_manager 延迟到首帧后初始化,1s 兜底防 postFrame 丢失。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _postFirstFrameInit();
      });
      Future.delayed(const Duration(seconds: 1), _postFirstFrameInit);
    } catch (e, s) {
      debugPrint('$_tag _init error: $e\n$s');
    }
  }

  void _postFirstFrameInit() {
    if (_postFirstFrameInitDone) return;
    _postFirstFrameInitDone = true;
    _initWindowManager();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      await themeViewModel.load();
      await fontSizeViewModel.load();
      await localeViewModel.load();
      // 语言设置加载完成后按最终语言刷新一次标题。
      await _updateWindowTitle();
    } catch (e) {
      debugPrint('$_tag load preferences failed: $e');
    }
  }

  Future<void> _initWindowManager() async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));
      await windowManager.ensureInitialized();
      _windowManagerInited = true;
      windowManager.addListener(this);
      await windowManager.waitUntilReadyToShow();
      await applyWindowStyle();
    } catch (e, s) {
      debugPrint('$_tag windowManager init error: $e\n$s');
    }
  }

  /// 更新窗口标题。与 _loadPreferences 存在并发:偏好加载可能先于
  /// window_manager 初始化完成,此时不得触碰 windowManager
  /// (见 _windowManagerInited 注释)。
  Future<void> _updateWindowTitle() async {
    if (!_windowManagerInited) return;
    final locale = basicLocaleListResolution(
      [
        localeViewModel.locale ??
            WidgetsBinding.instance.platformDispatcher.locale
      ],
      AppLocalizations.supportedLocales,
    );
    final title = windowTitle(lookupAppLocalizations(locale));
    try {
      await windowManager.setTitle(title);
    } catch (e) {
      debugPrint('$_tag setTitle failed: $e');
    }
  }

  /// 供子类在内容变化(如搜索窗切换目标会话)后刷新标题,内部走门闩。
  Future<void> updateWindowTitle() => _updateWindowTitle();

  // -------------------------------------------------------------- 窗口事件

  @override
  void onWindowClose() async {
    await WindowEventChannel.invoke(0, '$windowKind.windowClosed', {
      'windowId': windowId,
    });
  }

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FontSizeViewModel>.value(
            value: fontSizeViewModel),
        ChangeNotifierProvider<ThemeViewModel>.value(value: themeViewModel),
        ChangeNotifierProvider<LocaleViewModel>.value(value: localeViewModel),
        ...extraProviders,
      ],
      child: Consumer2<LocaleViewModel, FontSizeViewModel>(
        builder: (context, localeViewModel, fontSizeViewModel, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: localeViewModel.locale,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: themeMode,
            builder: (context, child) {
              // 与主窗口一致:字号完全由 app 内的「字体大小」设置接管
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler:
                      TextScaler.linear(fontSizeViewModel.textScaleFactor),
                ),
                // 子窗口同样覆盖全局水印(userId 走 Imclient.currentUserId 回退)
                child: Stack(
                  children: [
                    child!,
                    const Positioned.fill(child: WatermarkOverlay()),
                  ],
                ),
              );
            },
            home: _isReady ? buildHome(context) : buildLoading(context),
          );
        },
      ),
    );
  }
}
