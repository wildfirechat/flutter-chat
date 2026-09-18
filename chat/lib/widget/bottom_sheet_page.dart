import 'dart:math';

import 'package:flutter/material.dart';

/// 移动端"从底部升起的半屏页面"(微信的"选择提醒的人"那种形态)。
///
/// 与整页 push 的差别不只是动画方向:半屏弹窗盖在原页面上,下面的输入框、消息列表
/// 都还看得见,用户知道自己没离开会话 —— @ 提醒这种"选完就回来接着打字"的操作,
/// 用弹窗比整页连贯。
///
/// **满屏的场景(如转发)不要走这里**,直接用 `MaterialPageRoute(fullscreenDialog: true)`:
/// 移动端主题里的 Cupertino 转场会把它做成从底部升起的整页(见 theme/page_transitions.dart),
/// 状态栏留白、键盘避让、返回键都由 Scaffold 自己处理;而弹窗路由会抹掉顶部安全区
/// (`ModalBottomSheetRoute` 里的 `MediaQuery.removePadding(removeTop: true)`),
/// 满屏时还得把状态栏高度手工补回来。
///
/// [heightFactor] 是弹窗高度占可用高度的比例。用户在弹窗内唤起键盘时,弹窗整体抬到
/// 键盘之上、高度同时收进剩余空间,看起来是"往上长"(与微信一致);弹窗拉起那一刻
/// 正在收起的那次键盘不算数,见 _BottomSheetPageShellState 里的 _trackKeyboard。
Future<T?> showBottomSheetPage<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double heightFactor = 0.72,
  bool useRootNavigator = false,
}) {
  assert(heightFactor > 0 && heightFactor <= 1);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    // 半屏弹窗的高度自己算,不能被 SDK 默认的 9/16 上限截住
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (sheetContext) => _BottomSheetPageShell(
      heightFactor: heightFactor,
      child: builder(sheetContext),
    ),
  );
}

class _BottomSheetPageShell extends StatefulWidget {
  const _BottomSheetPageShell({
    required this.heightFactor,
    required this.child,
  });

  final double heightFactor;
  final Widget child;

  @override
  State<_BottomSheetPageShell> createState() => _BottomSheetPageShellState();
}

class _BottomSheetPageShellState extends State<_BottomSheetPageShell> {
  /// 顶部永远留一条缝:既露出下面的页面(弹窗不是新页面),也保证弹窗顶不到状态栏里去。
  /// 键盘顶上来把弹窗撑高时,这条缝就是高度的上限。
  static const double _topGap = 56;

  /// 开场那一次键盘要不要算进高度里。
  ///
  /// 弹窗常常是在"键盘正在收起"的瞬间建起来的 —— 在输入框里敲 '@' 拉起选人弹窗就是
  /// 这样:焦点被弹窗路由抢走,键盘开始回落,但第一帧的 viewInsets 还是满的。照它算
  /// 高度的话,弹窗会先蹿到离屏幕顶只剩 [_topGap] 的位置,再跟着键盘缩回去 —— 看起来
  /// 就是一次抖动。所以初始键盘一律当 0,等它真的收完(或用户在弹窗里主动点搜索框)
  /// 再开始避让;那之后的键盘是用户自己唤起的,弹窗往上长才是他要的。
  bool _trackKeyboard = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // viewInsets 变化本身就会触发重建,这里只需在重建前把闸门拨到位,不用 setState。
    if (!_trackKeyboard && MediaQuery.viewInsetsOf(context).bottom == 0) {
      _trackKeyboard = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double keyboard =
        _trackKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0.0;

    // 用 LayoutBuilder 而不是 MediaQuery.size:平板两栏时弹窗开在右栏的嵌套
    // Navigator 里,可用高度是那一栏的,不是整屏的。
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxHeight = constraints.maxHeight;
        final double available =
            (maxHeight - keyboard - _topGap).clamp(0.0, maxHeight);
        final double height = min(maxHeight * widget.heightFactor, available);

        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          // 高度已经把键盘算进去了,子树(Scaffold 默认 resizeToAvoidBottomInset)
          // 再按 viewInsets 避让一次就是双份留白。
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: SizedBox(height: height, child: widget.child),
          ),
        );
      },
    );
  }
}
