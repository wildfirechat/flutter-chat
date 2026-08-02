# window_manager 0.4.3(本地补丁版)

来源:pub.dev `window_manager: 0.4.3`(未包含上游的 `example/` 目录)。
改动了 `linux/window_manager_plugin.cc`(补丁 1、2、4)与
`windows/window_manager_plugin.cpp`(补丁 3),macOS / Dart 侧与上游一致。
升级 window_manager 时需要把下面的补丁重新套用。

## 补丁:Linux 插件销毁时摘掉所有回调(修多窗口 use-after-free 崩溃)

### 问题

`window_manager_plugin_register_with_registrar()` 会做两件事:

1. 把 9 个信号回调挂到本引擎所在的 GtkWindow 上(`delete_event` /
   `focus-in-event` / `hide` / `event-after` …),`user_data` 都是 plugin 自身;
2. 调 `g_signal_add_emission_hook()` 在 **GtkWidget 类型**上挂一个全局
   `button-press-event` 钩子(`on_mouse_press`),`user_data` 同样是 plugin,
   且丢弃了返回的 hook id、没有传 destroy notify。

原实现的 `dispose` 只清了 `css_provider` 和 `title_bar_style_`,上面两类回调
一个都没摘。

主窗口的 plugin 与进程同寿,所以单窗口应用看不出问题。但本项目用
desktop_multi_window 开子窗口(通话 / 媒体预览 / 朋友圈 / 搜索),
`linux/runner/my_application.cc` 的 window-created 回调会给每个子窗口引擎再注册
一次 window_manager,于是每开一个子窗口就多一个全局 emission hook。

子窗口关闭时(`gtk_widget_destroy` → 引擎 shutdown),引擎会关闭 messenger 上的
所有 channel,`fl_method_channel` 的 `channel_closed_cb()` 会调用
`fl_method_channel_set_method_call_handler` 注册的 destroy notify,也就是
`g_object_unref(plugin)`(见 flutter engine
`shell/platform/linux/fl_method_channel.cc`)。plugin 只有这一个引用,于是被释放,
而全局 emission hook 仍然指着这块内存。

之后主窗口里的**任意一次鼠标点击**都会命中该钩子:

```
GLib-GObject-CRITICAL: invalid uninstantiatable type '(null)' in cast to 'WindowManagerPlugin'
GLib-GObject-CRITICAL: invalid cast from 'GtkCssStaticStyle' to 'WindowManagerPlugin'
```

`G_TYPE_CHECK_INSTANCE_CAST` 只告警不拦截,`on_mouse_press` 接着
`memcpy(&plugin->_event_button, …)` 把已被 GTK 复用的内存写坏 → 进程崩溃
(表现为 `Lost connection to device.`)。同理,窗口销毁过程中(FlView 先于窗口销毁)
GtkWindow 还会继续发 `hide` / `destroy` 等信号,也会打到已释放的 plugin 上。

### 改动

`linux/window_manager_plugin.cc`,均以 `[PATCH]` 注释标出:

- `struct _WindowManagerPlugin` 新增 `GtkWindow* window` 与
  `gulong mouse_press_hook_id`;
- 注册时记下 emission hook id,并用 `g_object_add_weak_pointer()` 记住信号所挂的
  窗口(窗口先销毁时该指针自动置空);
- `window_manager_plugin_dispose()` 中:
  `g_signal_remove_emission_hook()` 摘掉全局钩子、
  `g_signal_handlers_disconnect_matched(…, G_SIGNAL_MATCH_DATA, …, self)` 断开
  窗口上所有以 self 为 user_data 的回调、清空 `_event_box`,并释放注册时持有的
  `channel` / `registrar` 引用(原实现这两个引用是泄漏的)。

释放顺序是安全的:plugin 的 dispose 发生在 `channel_closed_cb` 内部,此时 channel
仍被该函数的 `g_autoptr` 持有一份引用,plugin 这边 unref 只是把计数从 2 降到 1,
channel 的 dispose 之后才发生,且那时 `method_call_handler_destroy_notify` 已被置空,
不会二次释放 plugin。

## 补丁 2:指针设备 / 窗口的空指针保护

`pop_up_window_menu` / `start_dragging` / `start_resizing` 原实现直接把
`gdk_seat_get_pointer()` 的结果喂给 `gdk_device_get_position()`。seat 上没有指针
设备时(GdkSeat 尚未就绪、无鼠标、部分虚拟机环境)该函数返回 NULL,于是:

```
Gtk-CRITICAL **: assertion 'GDK_IS_DEVICE (device)' failed
```

而且 `start_dragging` 会拿着未初始化的 `root_x/root_y` 去
`gtk_window_begin_move_drag`,`pop_up_window_menu` 会把 NULL device 塞进自己伪造的
`GdkEvent` 里。

补丁给这三处加了空指针判断(顺带判断 `get_window()` 是否已经为 NULL——视图销毁后
它会返回 NULL),取不到设备就打一条 warning 并返回 false,不再往下走。

## 补丁 3:Windows 的 MethodChannel 改成 plugin 实例成员(修多窗口下主窗口事件失效)

### 问题

`windows/window_manager_plugin.cpp` 上游把 channel 放在匿名 namespace 里:

```cpp
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel = nullptr;

void WindowManagerPlugin::RegisterWithRegistrar(...) {
  channel = std::make_unique<...>(registrar->messenger(), "window_manager", ...);
  ...
}
WindowManagerPlugin::~WindowManagerPlugin() { ...; channel = nullptr; }
void WindowManagerPlugin::_EmitEvent(...) { channel->InvokeMethod("onEvent", ...); }
```

这是**进程级单例**,单窗口应用无所谓。本项目用 desktop_multi_window 开子窗口
(通话 / 媒体预览 / 朋友圈 / 搜索),`windows/runner/flutter_window.cpp` 的
window-created 回调会给每个子窗口引擎再注册一次 window_manager,于是:

- 子窗口一开,全局 `channel` 被换成子窗口引擎那份。此后**主窗口**的
  `_EmitEvent` 全都发到子窗口 isolate——主窗口的 `onWindowClose` /
  `onWindowFocus` / `onWindowBlur` / `onWindowResize` 等事件在主窗口 Dart 侧
  再也收不到(主窗口点 X 不走"最小化到托盘"、前后台判断失效);
- 反过来,主窗口的 WM_CLOSE 会把 `onWindowClose` 投递到通话子窗口的 isolate,
  触发那边的挂断 + `voip.windowClosed`;
- 子窗口关闭时析构函数把全局 `channel` 置空,主窗口的窗口事件**永久失效**。

方法调用方向没问题(handler 绑在各自 plugin 实例上,`native_window` 也是各自
`ensureInitialized` 时从本引擎的 view 取的),坏掉的只有事件回传方向。

### 改动

`windows/window_manager_plugin.cpp`,以 `[PATCH]` 注释标出:

- 删掉匿名 namespace 里的全局 `channel`,改为 `WindowManagerPlugin` 的私有成员;
- `RegisterWithRegistrar` 先建 plugin 再建 channel(`plugin->channel = ...`),
  handler 仍绑在同一个 plugin 实例上;
- 析构与 `_EmitEvent` 里的 `channel` 自然解析为 `this->channel`,代码不变。

macOS 侧 `WindowManagerPlugin` 本来就是每个 registrar 一个实例、channel 存实例
属性,Linux 侧 channel 存在 `_WindowManagerPlugin` 结构体里,都没有这个问题。

> 同类问题:`tray_manager` 的 Windows / Linux 实现也用进程级全局记录最后一次
> 注册的 channel / plugin。托盘只有主窗口用得到,所以三个平台的
> window-created 回调里都**不注册** TrayManagerPlugin,而不是给它打补丁。

## 补丁 4:Linux 窗口已销毁时统一拦下 windowManager 调用(修关子窗口后崩溃)

### 问题

Linux 子窗口(desktop_multi_window)的**引擎比它的 GtkWindow 活得久**:关窗走
`gtk_widget_destroy`,FlView 随之析构,但引擎和 Dart isolate 还在跑,之前排队的
`windowManager` 调用照样会打进插件。此时 registrar 里的 FlView 弱引用已失效,
`get_window()` 返回 nullptr,而上游每个 handler 都直接把它当有效 `GtkWindow` 用。

GTK 里不少函数是**先解引用 `window->priv`、再做 `g_return_if_fail`** 的,
`gtk_window_get_titlebar()` 就是,于是 NULL 直接段错误(2026-08-02 gdb 实证):

```
Thread 1 "wildfirechat" received signal SIGSEGV
#0  gtk_window_get_titlebar () from /lib/x86_64-linux-gnu/libgtk-3.so.0
#1  get_header_bar (window=0x0) at window_manager_plugin.cc:504
#2  set_title_bar_style (…)      <- 子窗口 applyWindowStyle 里的 setTitleBarStyle
#3  window_manager_plugin_handle_method_call
```

复现:反复开关同一类子窗口(日报 webview 窗),赶在子窗口 `applyWindowStyle`
(postFrame + 50ms 才开始)完成之前关窗。补丁 2 只给三个方法加了判断,
其余四十多个方法同样中招。

### 改动

`linux/window_manager_plugin.cc`,以 `[PATCH]` 注释标出:

- `get_window()` 增加 `GTK_IS_WINDOW(toplevel)` 判断。FlView 被摘下来重挂时
  (`webview_all_linux` 的 `ensure_overlay` 会这么干)`gtk_widget_get_toplevel()`
  返回的是 FlView 自己,`GTK_WINDOW()` 只告警不拦截,拿去用一样是野指针;
- `window_manager_plugin_handle_method_call()` 开头统一判断:除
  `ensureInitialized` / `waitUntilReadyToShow`(纯应答)与 `setBrightness`
  (只动 GtkSettings)外,`get_window()` 为空一律回
  `window_destroyed` 错误,不再往下走。Dart 侧收到 PlatformException,
  子窗口基类 `SubWindowAppBase` 的各处 try/catch 会打日志忽略。

> 这只是"不崩"的兜底。根因是 Linux 子窗口关闭后引擎没被销毁(僵尸引擎:Dart
> 还在跑、还在出帧),那条另有其账,见 chat 侧记录。
