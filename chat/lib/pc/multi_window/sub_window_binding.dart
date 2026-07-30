import 'package:flutter/widgets.dart';

/// 子窗口（desktop_multi_window 子引擎，通话/媒体预览等）专用 binding。
///
/// macOS 上多引擎子窗口会收到错误的 hidden/paused 生命周期状态
/// （flutter/flutter#133533），framework 随即关闭帧调度
/// （SchedulerBinding.framesEnabled=false，scheduleFrame 变 no-op）：
/// setState/Timer 只更新状态不再产帧——表现为通话计时不走、来电窗口停在
/// 首帧黑屏，只有调整窗口大小才被强制刷出一帧；首帧后的
/// addPostFrameCallback 也不执行，window_manager 一直未初始化，挂断关窗时
/// Swift 侧 close 因 _mainWindow 为 nil 强解包直接崩溃进程。
///
/// 子窗口生命周期短且必须持续渲染（计时、来电 UI、视频画面、图片加载），
/// 这里把所有会停帧的状态一律降级为 inactive，保证帧调度常开。
class SubWindowWidgetsBinding extends WidgetsFlutterBinding {
  static SubWindowWidgetsBinding? _instance;

  static SubWindowWidgetsBinding ensureInitialized() {
    _instance ??= SubWindowWidgetsBinding();
    return _instance!;
  }

  @override
  void handleAppLifecycleStateChanged(AppLifecycleState state) {
    final AppLifecycleState effective;
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        effective = AppLifecycleState.inactive;
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        effective = state;
    }
    if (effective != state) {
      debugPrint(
          'SubWindowWidgetsBinding remap lifecycle $state -> $effective');
    }
    super.handleAppLifecycleStateChanged(effective);
  }
}
