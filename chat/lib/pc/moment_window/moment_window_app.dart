import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imclient/imclient_method_channel.dart';
import 'package:momentclient/momentclient.dart';
import 'package:momentkit/momentkit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodel/locale_view_model.dart';
import '../../viewmodel/theme_view_model.dart';
import '../multi_window/window_event_channel.dart';
import 'moment_ipc.dart';
import 'moment_window_imclient_channel.dart';

/// 朋友圈窗口的入口 Widget。
///
/// 运行在独立的 Flutter Engine / Dart isolate 中，不连接 IM；
/// IM 调用经 [MomentWindowImclientChannel] 转发到主窗口执行，
/// 与 Call 窗口（CallWindowApp）同构。
class MomentWindowApp extends StatefulWidget {
  final int windowId;
  final Map<String, dynamic> arguments;

  const MomentWindowApp({
    super.key,
    required this.windowId,
    required this.arguments,
  });

  @override
  State<MomentWindowApp> createState() => _MomentWindowAppState();
}

class _MomentWindowAppState extends State<MomentWindowApp> with WindowListener {
  static const String _tag = 'MomentWindowApp';

  late final ThemeViewModel _themeViewModel;
  late final LocaleViewModel _localeViewModel;

  /// 主窗口转发来的刷新信号（feedId：单条刷新；null：全量刷新）。
  final StreamController<int?> _refreshController =
      StreamController<int?>.broadcast();

  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _themeViewModel = ThemeViewModel();
    _localeViewModel = LocaleViewModel(autoLoad: false);
    _init();
  }

  Future<void> _init() async {
    try {
      print('$_tag _init start, windowId=${widget.windowId}');

      // 朋友圈窗口 isolate 中 Imclient 没有自己连接 IM，先设置当前用户。
      final selfUserId = widget.arguments['_selfUserId'] as String? ?? '';
      ImclientPlatform.instance.userId = selfUserId;

      // 1. 替换 IM 通道为代理通道。
      ImclientPlatform.instance.channel = MomentWindowImclientChannel();

      // 2. 注册朋友圈消息内容类型（仅 Dart 层解码用）。
      MomentClient.init((comment) {}, (feed) {});

      // 3. 监听主窗口转发来的事件。
      final channel = WindowEventChannel();
      channel.register(MomentWindowEvents.refresh, _handleRefresh);
      channel.listen();

      // 4. 通知主窗口已就绪。
      await WindowEventChannel.invoke(0, MomentWindowEvents.ready, {
        'windowId': widget.windowId,
      });

      setState(() => _isReady = true);

      // 与 Call 窗口一致：window_manager 延迟到首帧后初始化。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _postFirstFrameInit();
      });
      Future.delayed(const Duration(seconds: 1), _postFirstFrameInit);
    } catch (e, s) {
      print('$_tag _init error: $e\n$s');
    }
  }

  bool _postFirstFrameInitDone = false;

  void _postFirstFrameInit() {
    if (_postFirstFrameInitDone) return;
    _postFirstFrameInitDone = true;
    _initWindowManager();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      await _themeViewModel.load();
      await _localeViewModel.load();
    } catch (e) {
      print('$_tag load preferences failed: $e');
    }
  }

  Future<void> _initWindowManager() async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      await windowManager.waitUntilReadyToShow();
      await windowManager.setTitle('朋友圈');
      await windowManager.setMinimumSize(const Size(480, 600));
      await windowManager.show();
      await windowManager.focus();
    } catch (e, s) {
      print('$_tag windowManager init error: $e\n$s');
    }
  }

  Future<dynamic> _handleRefresh(dynamic args) async {
    final feedId = args is Map ? args['feedId'] as int? : null;
    _refreshController.add(feedId);
    return null;
  }

  @override
  void onWindowClose() async {
    await WindowEventChannel.invoke(0, MomentWindowEvents.windowClosed, {
      'windowId': widget.windowId,
    });
  }

  @override
  void dispose() {
    _refreshController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeViewModel>.value(value: _themeViewModel),
        ChangeNotifierProvider<LocaleViewModel>.value(value: _localeViewModel),
      ],
      child: _buildMaterialApp(),
    );
  }

  Widget _buildMaterialApp() {
    final light = ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF576B95)),
      useMaterial3: true,
    );
    final dark = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF576B95), brightness: Brightness.dark),
      useMaterial3: true,
    );
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _localeViewModel.locale,
      theme: light,
      darkTheme: dark,
      themeMode: _themeViewModel.themeMode,
      home: _isReady
          ? FeedListPage(refreshStream: _refreshController.stream)
          : const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
    );
  }
}
