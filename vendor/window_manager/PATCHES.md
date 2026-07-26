# window_manager 0.4.3(本地补丁版)

来源:pub.dev `window_manager: 0.4.3`(未包含上游的 `example/` 目录)。
仅改动 `linux/window_manager_plugin.cc`,macOS / Windows / Dart 侧与上游一致。
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
