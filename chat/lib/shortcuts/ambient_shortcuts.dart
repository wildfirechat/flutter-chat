/// 环境快捷键(ambient shortcuts):属于窗口/页面、与"此刻谁持有焦点"无关的快捷键。
///
/// 为什么不挂在 Focus 节点上:按键从主焦点节点**向上**派发,挂在页面里的
/// `Focus(autofocus: true)` 只在它自己持有焦点时才收得到。而焦点会被别处随手拿走
/// ——输入框 `unfocus()` 会把主焦点交还给上层 FocusScope(页面 Focus 的祖先),
/// 从此按键永远绕过它,直到页面重新挂载。会话页的"只能复制一次"、子窗口的
/// Ctrl+W 失效,都是这一个坑。
///
/// 这里把这类快捷键从焦点树里摘出来,登记到 FocusManager 的全局处理器上:
///
/// - [ShortcutPhase.afterFocus](默认):焦点链没人消费才轮到我们。输入框有选区时
///   Cmd/Ctrl+C 归输入框,聚焦的按钮吃掉空格,都是对的,不需要额外判断。
/// - [ShortcutPhase.beforeFocus]:抢在焦点链之前。**只给方向键用**——Flutter 的
///   焦点遍历(DirectionalFocusAction)会无条件吞掉方向键,afterFocus 根本收不到。
///   这一档会自动跳过"文本输入框持有焦点"的情况,否则会抢掉光标移动。
///
/// 派发规则:后注册者先匹配(弹层/预览天然压过页面,页面压过 shell)→ 跳过
/// `isActive` 为假的登记 → handler 返回 false 表示"我不处理",继续往下沉。
///
/// ## 全表(改动时请同步维护)
///
/// | 快捷键 | 归属 | 阶段 |
/// |---|---|---|
/// | Esc | 会话页:退出多选 | afterFocus |
/// | Cmd/Ctrl+C | 会话页:复制气泡里的部分选区 | afterFocus |
/// | Cmd/Ctrl+F | PC 主窗:打开搜索 | afterFocus |
/// | Cmd/Ctrl+W | PC 主窗:隐藏窗口 / 子窗口:关闭 | afterFocus |
/// | ↑ ↓ | PC 主窗:上下切会话 | beforeFocus |
/// | ← → | 媒体预览:上下一张 | beforeFocus |
/// | 空格 | 媒体预览:图片关窗 / 视频播放暂停 | afterFocus |
/// | Esc | 媒体预览:关闭 | afterFocus |
/// | Cmd/Ctrl+C | 媒体预览:复制当前图片 | afterFocus |
///
/// 焦点内快捷键(输入框回车发送、@ 弹层上下键、搜索框 Esc)不走这里——它们本来
/// 就属于某个控件,继续挂在控件自己的 Focus 上是对的。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 返回 true 表示"我处理了这个按键";返回 false 让给下一个登记者。
typedef ShortcutHandler = bool Function();

enum ShortcutPhase {
  /// 焦点链没人处理才轮到(默认,适用于绝大多数)
  afterFocus,

  /// 抢在焦点链之前(方向键专用,见库文档)
  beforeFocus,
}

/// Cmd(macOS)或 Ctrl(Windows/Linux)+ 某键。
///
/// 沿用项目既有语义:两个修饰键都接受,不按平台区分——原来各处写的都是
/// `isControlPressed || isMetaPressed`。
class CmdOrCtrl extends ShortcutActivator {
  const CmdOrCtrl(this.trigger, {this.shift = false});

  final LogicalKeyboardKey trigger;
  final bool shift;

  @override
  Iterable<LogicalKeyboardKey> get triggers => <LogicalKeyboardKey>[trigger];

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (event is! KeyDownEvent) {
      return false;
    }
    if (event.logicalKey != trigger) {
      return false;
    }
    if (!state.isControlPressed && !state.isMetaPressed) {
      return false;
    }
    return state.isShiftPressed == shift;
  }

  @override
  String debugDescribeKeys() =>
      '${shift ? 'Shift + ' : ''}Cmd/Ctrl + ${trigger.keyLabel}';
}

/// 当前持有焦点的是不是文本输入框。beforeFocus 档内部据此让路,
/// 需要自行判断的地方(比如某个 handler 想更细致地区分)也可以直接用。
bool isTextInputFocused() {
  final BuildContext? context = FocusManager.instance.primaryFocus?.context;
  if (context == null) {
    return false;
  }
  bool editable = context.widget is EditableText;
  if (!editable) {
    context.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        editable = true;
        return false;
      }
      return true;
    });
  }
  return editable;
}

/// 一次登记的句柄,[dispose] 后不再参与派发。
class AmbientShortcutRegistration {
  AmbientShortcutRegistration._(
      this._owner, this.bindings, this.isActive, this.debugLabel);

  final AmbientShortcuts _owner;
  final Map<ShortcutActivator, ShortcutHandler> bindings;
  final bool Function() isActive;
  final String? debugLabel;
  bool _disposed = false;

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _owner._unregister(this);
  }
}

/// 环境快捷键注册表。整个 engine(主窗口/每个子窗口各一份)共用一个实例。
class AmbientShortcuts {
  AmbientShortcuts._();

  static final AmbientShortcuts instance = AmbientShortcuts._();

  final List<AmbientShortcutRegistration> _beforeFocus =
      <AmbientShortcutRegistration>[];
  final List<AmbientShortcutRegistration> _afterFocus =
      <AmbientShortcutRegistration>[];

  /// 已挂上处理器的那个 FocusManager。记实例而不是布尔开关:FocusManager 可能
  /// 被换掉(测试环境每个用例换一个),挂在旧实例上的处理器再也不会被调用。
  FocusManager? _installedOn;

  /// 登记一组快捷键。[isActive] 每次派发都会问一遍,用来表达"这个页面此刻是否该响应"。
  AmbientShortcutRegistration register({
    required Map<ShortcutActivator, ShortcutHandler> bindings,
    required bool Function() isActive,
    ShortcutPhase phase = ShortcutPhase.afterFocus,
    String? debugLabel,
  }) {
    _install();
    final registration =
        AmbientShortcutRegistration._(this, bindings, isActive, debugLabel);
    _listFor(phase).add(registration);
    return registration;
  }

  void _unregister(AmbientShortcutRegistration registration) {
    _beforeFocus.remove(registration);
    _afterFocus.remove(registration);
  }

  List<AmbientShortcutRegistration> _listFor(ShortcutPhase phase) =>
      phase == ShortcutPhase.beforeFocus ? _beforeFocus : _afterFocus;

  void _install() {
    final FocusManager manager = FocusManager.instance;
    if (identical(_installedOn, manager)) {
      return;
    }
    _installedOn = manager;
    manager.addEarlyKeyEventHandler(_dispatchBeforeFocus);
    manager.addLateKeyEventHandler(_dispatchAfterFocus);
  }

  KeyEventResult _dispatchBeforeFocus(KeyEvent event) {
    // 输入框在打字时,方向键归光标
    if (isTextInputFocused()) {
      return KeyEventResult.ignored;
    }
    return _dispatch(_beforeFocus, event);
  }

  KeyEventResult _dispatchAfterFocus(KeyEvent event) =>
      _dispatch(_afterFocus, event);

  KeyEventResult _dispatch(
      List<AmbientShortcutRegistration> registrations, KeyEvent event) {
    // 后注册者先匹配;派发期间 handler 可能改动列表(如关闭页面),先拷一份
    for (final registration in registrations.reversed.toList(growable: false)) {
      if (registration._disposed || !registration.isActive()) {
        continue;
      }
      for (final MapEntry<ShortcutActivator, ShortcutHandler> entry
          in registration.bindings.entries) {
        if (entry.key.accepts(event, HardwareKeyboard.instance) &&
            entry.value()) {
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }
}

/// 给 State 用的登记器:initState 登记、dispose 注销,并自带
/// "widget 还在树上 + 所在路由没被别的页面盖住"的生效条件。
///
/// 覆写 [ambientShortcuts] / [ambientShortcutsBeforeFocus] 声明按键表,
/// 需要额外条件时覆写 [ambientShortcutsActive]。
mixin AmbientShortcutsMixin<T extends StatefulWidget> on State<T> {
  AmbientShortcutRegistration? _afterFocusRegistration;
  AmbientShortcutRegistration? _beforeFocusRegistration;
  ModalRoute<dynamic>? _shortcutRoute;

  Map<ShortcutActivator, ShortcutHandler> get ambientShortcuts =>
      const <ShortcutActivator, ShortcutHandler>{};

  Map<ShortcutActivator, ShortcutHandler> get ambientShortcutsBeforeFocus =>
      const <ShortcutActivator, ShortcutHandler>{};

  bool get ambientShortcutsActive =>
      mounted && _shortcutRoute?.isCurrent != false;

  @override
  void initState() {
    super.initState();
    final Map<ShortcutActivator, ShortcutHandler> after = ambientShortcuts;
    final Map<ShortcutActivator, ShortcutHandler> before =
        ambientShortcutsBeforeFocus;
    if (after.isNotEmpty) {
      _afterFocusRegistration = AmbientShortcuts.instance.register(
        bindings: after,
        isActive: () => ambientShortcutsActive,
        debugLabel: '$runtimeType',
      );
    }
    if (before.isNotEmpty) {
      _beforeFocusRegistration = AmbientShortcuts.instance.register(
        bindings: before,
        isActive: () => ambientShortcutsActive,
        phase: ShortcutPhase.beforeFocus,
        debugLabel: '$runtimeType (beforeFocus)',
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在 build 阶段取好路由,派发时只读 isCurrent 这个普通 getter,
    // 不在按键回调里做 InheritedWidget 查找
    _shortcutRoute = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _afterFocusRegistration?.dispose();
    _beforeFocusRegistration?.dispose();
    super.dispose();
  }
}
