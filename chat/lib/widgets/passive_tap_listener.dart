import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// 旁听子树里的"轻点"并回调 [onTap]:自己不进手势竞技场,也不吃掉这一下点击,
/// 子树里的按钮、输入框照常响应。
///
/// 用在"点到别处就收起浮层"这类场景。这种活儿外层挂 `GestureDetector.onTap`
/// 是不成的:子树里到处是自带识别器的控件(按钮、输入框、头像),竞技场里内层
/// 赢在前头,外层的 onTap 根本轮不上 —— 表现就是点按钮时浮层不消失。
///
/// [Listener] 拿到的是裸指针事件,"算不算一次轻点"由这里自己判,三条都得满足:
/// - 主键/手指按下:外接鼠标的右键、侧键不算 —— 右键通常正要弹的就是针对当前
///   状态(比如选区)的菜单,当成点击处理会把它要用的状态先清掉;
/// - 位移不超过 [kTouchSlop]:滑动列表、拖文本选择手柄都不算点击;
/// - 按下到抬起不超过 [kLongPressTimeout]:浮层本身常常就是长按弹出来的,
///   长按那一下自己的抬起不能把刚弹出来的浮层收掉。
class PassiveTapListener extends StatefulWidget {
  const PassiveTapListener({
    super.key,
    required this.onTap,
    required this.child,
  });

  /// 认出一次轻点后回调。点击不会被吃掉,子树里的控件仍会照常收到这一下
  final VoidCallback onTap;

  final Widget child;

  @override
  State<PassiveTapListener> createState() => _PassiveTapListenerState();
}

class _PassiveTapListenerState extends State<PassiveTapListener> {
  /// 正在判定中的那一下。多指时只跟按下的第一指,其余指的事件按 pointer 号滤掉
  ({int pointer, Offset position, Duration timeStamp})? _pending;

  void _handlePointerDown(PointerDownEvent event) {
    if (_pending != null || event.buttons != kPrimaryButton) {
      return;
    }
    _pending = (
      pointer: event.pointer,
      position: event.position,
      timeStamp: event.timeStamp,
    );
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final pending = _pending;
    if (pending != null &&
        pending.pointer == event.pointer &&
        (event.position - pending.position).distance > kTouchSlop) {
      _pending = null;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final pending = _pending;
    if (pending == null || pending.pointer != event.pointer) {
      return;
    }
    _pending = null;
    if (event.timeStamp - pending.timeStamp > kLongPressTimeout) {
      return;
    }
    widget.onTap();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_pending?.pointer == event.pointer) {
      _pending = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // 子树里的空白处(没有控件接管的地方)点下去也要认
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }
}
