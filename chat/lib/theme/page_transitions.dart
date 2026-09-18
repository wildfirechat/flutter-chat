import 'package:flutter/material.dart';

/// 移动形态(手机 + 平板)的页面转场。
///
/// Material 在 Android 上的默认转场是 [ZoomPageTransitionsBuilder] —— 新页面
/// 从中心缩放淡入,读不出"进了一层"这件事;而 app 里绝大多数移动端跳转都是一条
/// 往下钻的栈(会话 → 群资料 → 成员资料…),微信/iOS 那种横向推拉才把层级关系
/// 表达出来。这里把移动端统一到 [CupertinoPageTransitionsBuilder]:
///
/// - 新页从右侧滑入,左缘带一道投影;旧页同时左移 1/3 做视差,返回时逆放;
/// - 左边缘 20pt 内横滑可返回(iOS 上本来就有,Android 上跟微信一致地补齐);
/// - `fullscreenDialog: true` 的路由自动变成从底部升起。
///
/// iOS 端行为与之前逐位相同(本来就是这支),这次改的是 Android/鸿蒙。
///
/// 时长走 SDK 的 [CupertinoRouteTransitionMixin.kTransitionDuration](500ms,
/// 对齐 iOS 18):曲线是 `fastEaseInToSlowEaseOut`,位移在前 1/3 就走完九成,
/// 尾巴只是缓停,手感并不拖沓。真要更快,继承
/// [CupertinoPageTransitionsBuilder] 覆写 `transitionDuration` 即可 ——
/// `MaterialPageRoute` 的时长就是从这里取的。
class AppPageTransitions {
  AppPageTransitions._();

  /// 每个平台一支,取值相同。
  ///
  /// 之所以遍历 [TargetPlatform.values] 而不是只写 android/iOS:鸿蒙的 Flutter
  /// fork 里 `defaultTargetPlatform` 取的是 `TargetPlatform.ohos`,这个枚举值在
  /// 标准 SDK 上写不出来(编译不过);而 builders 里查不到的平台会被 SDK 兜底回
  /// [ZoomPageTransitionsBuilder] —— 只写两支的话,鸿蒙恰好漏在外面。
  /// 枚举里的桌面取值走不到:这套主题只在移动形态下挂上,见 AppTheme。
  static final PageTransitionsTheme mobile = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      for (final platform in TargetPlatform.values)
        platform: const CupertinoPageTransitionsBuilder(),
    },
  );
}
