import 'package:flutter/widgets.dart';

/// 所在页面被新页面盖住时回调 [onCovered](盖上去的那一下报一次,返回时不报)。
///
/// 用来收拾那些"挂在 Overlay 上、不跟着页面走"的浮层。Navigator 是把新路由插在
/// **上一个路由之上**的,而 [ContextMenuController](SelectionArea 的选区菜单走它)
/// 这类浮层直接插在根 Overlay 的最顶层 —— 新页面压不住它,浮层会直直地浮在新页面
/// 上面。选择手柄靠 CompositedTransformFollower 与页面联动,页面不绘制时自己就隐了;
/// 菜单没有这条链,得有人收。
///
/// 听的是所在路由的 `secondaryAnimation`(由"下一个路由"驱动),所以平板右栏那种
/// 嵌套 Navigator 里同样成立;页面不在任何路由里(比如直接摆在 PC 的栏里)时不做事。
///
/// 一处边界:按 [ModalRoute.canTransitionTo] 的规则,只有页面之间的 push 会驱动
/// secondaryAnimation,对话框、底部弹窗这类 PopupRoute 不会 —— 这些浮层要收,
/// 得由弹它们的地方自己收。
class RouteCoveredListener extends StatefulWidget {
  const RouteCoveredListener({
    super.key,
    required this.onCovered,
    required this.child,
  });

  final VoidCallback onCovered;

  final Widget child;

  @override
  State<RouteCoveredListener> createState() => _RouteCoveredListenerState();
}

class _RouteCoveredListenerState extends State<RouteCoveredListener> {
  Animation<double>? _secondaryAnimation;
  bool _covered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.secondaryAnimation;
    if (identical(animation, _secondaryAnimation)) {
      return;
    }
    _secondaryAnimation?.removeListener(_handleAnimationChanged);
    _secondaryAnimation = animation;
    _secondaryAnimation?.addListener(_handleAnimationChanged);
    // 换页面/换路由时按当前值对齐,免得把"本来就被盖着"当成刚盖上
    _covered = _isCovered;
  }

  bool get _isCovered => (_secondaryAnimation?.value ?? 0) > 0;

  void _handleAnimationChanged() {
    // 转场的每一帧都会回调,只在"没盖 → 盖上"那一下报一次
    final covered = _isCovered;
    if (covered == _covered) {
      return;
    }
    _covered = covered;
    if (covered) {
      widget.onCovered();
    }
  }

  @override
  void dispose() {
    _secondaryAnimation?.removeListener(_handleAnimationChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
