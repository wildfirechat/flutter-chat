# desktop_multi_window 0.2.1(本地补丁版)

来源:pub.dev `desktop_multi_window: 0.2.1`(未包含上游的 `example/` 目录)。
只改了 Linux 侧的 `linux/flutter_window.cc` 与 `linux/base_flutter_window.cc`,
macOS / Windows / Dart 侧与上游一致。升级时需要把下面的补丁重新套用。

引用方式:`chat/pubspec.yaml` 里 `desktop_multi_window: path: ../vendor/desktop_multi_window`。

## 补丁 1:子窗口的 FlView 先套一层 GtkOverlay(修 webview 子窗口必崩)

### 问题

Linux 的 `webview_all_linux` 把 WebKitGTK 的原生控件挂在 **FlView 的 GtkOverlay
父节点**上。父节点不是 overlay 时,它会在运行时自己补一个
(`linux/src/platform/flutter_view.cc` 的 `ensure_overlay`):

```
隐藏顶层窗口 → gtk_container_remove(parent, FlView) → 新建 GtkOverlay 挂回 parent
→ 把 FlView 加进 overlay → 显示顶层窗口
```

`gtk_container_remove()` 会 **unrealize** FlView,重新 add 之后再 realize。而
Flutter 的 Linux embedder(`shell/platform/linux/fl_view.cc` 的 `realize_cb`)
对 implicit view **没有任何"已经起过了"的判断**:

```c
static void realize_cb(FlView* self) {
  self->compositor = FL_COMPOSITOR(fl_compositor_opengl_new(self->engine, …));  // 覆盖旧的
  …
  if (!fl_engine_start(self->engine, &error)) { … }   // ← 第二次启动引擎
}
```

`fl_engine_start()` 里是 `embedder_api.Initialize(…, &self->engine)`:
**同一个 FlEngine 上又起了一整套引擎 shell**,`self->engine` 句柄被覆盖,旧 shell
成了孤儿 —— 它的 `io.flutter.ui` / `io.flutter.rast` / `io.flutter.io` 三个线程
永不退出(关窗时 `fl_engine_dispose` 只 Shutdown 得到新句柄),而旧 shell 注册的
回调 `user_data` 仍然是这个 FlEngine。同时 `fl_opengl_manager_create_contexts()`
会把三个 GdkGLContext 原地换掉,`realize_cb` 也会把 `self->compositor` 原地换掉。

于是孤儿光栅线程随时可能踩到已经被换掉/被释放的东西,三份 gdb 栈(2026-08-02,
Ubuntu 24.04 + llvmpipe)都是同一个根因:

```
# 开窗时就崩(光栅线程,还没关窗)
#0 fl_opengl_manager_make_current        ← self->main_context 所在的对象已不是原来那个
#1 fl_engine_gl_make_current
#2 flutter::EmbedderSurfaceGLSkia::GLContextMakeCurrent
#3 flutter::GPUSurfaceGLSkia::AcquireFrame

# 关窗后崩(光栅线程)
#0 g_hash_table_lookup                   ← 崩在 call *0x38(%r15),即取 hash_func:
#1 compositor_present_view_callback         FlEngine 已随窗口销毁,表指针是野的
#2 …EmbedderExternalViewEmbedder::SubmitFlutterView

# 关窗后崩(平台线程)
#0 gtk_window_get_titlebar               ← 见 vendor/window_manager/PATCHES.md 补丁 4
#1 get_header_bar (window=0x0)
#2 set_title_bar_style
```

佐证:第一份 gdb 日志里同时活着 **8 组** `io.flutter.{ui,rast,io}` 线程,整份日志
从头到尾没有一个引擎线程退出过 —— 每开一次日报 webview 子窗口就多一套孤儿 shell。
只有 webview 子窗口中招,图片预览 / 朋友圈 / 搜索 / 通话窗都正常,因为只有它会
建 WebView、才会触发 `ensure_overlay` 的重挂。

主窗口不受影响:`chat/linux/runner/my_application.cc` 早就预先建好了 GtkOverlay
(那边注释写的是"避免闪一下",其实避掉的是这个崩溃)。

### 改动

`linux/flutter_window.cc` 构造函数,以 `[PATCH]` 标出:在 `fl_view_new()`
**之前**建好 GtkOverlay 并挂进窗口,再把 FlView 加进 overlay。这样 FlView 从头到尾
只 realize 一次,`ensure_overlay` 走 `if (GTK_IS_OVERLAY(parent))` 的快路径直接复用。

> 约束:此后任何代码都不能再改子窗口 FlView 的父节点(重挂 = 重新 realize =
> 引擎被启动第二次)。同理,也不要在 window-created 回调里补 overlay —— 那时
> FlView 已经 realize 过了,补的动作本身就会触发这个 bug。

## 补丁 2:建窗时不再 show/hide,center() 真正算坐标(修"先弹黑窗、然后窗口挪位置")

### 问题

上游 `FlutterWindow::FlutterWindow()` 开头 `gtk_widget_show(window_)`、末尾又
`gtk_widget_hide(window_)`。中间夹着 `fl_view_new()`(建引擎、跑 Dart 入口,几百
毫秒),所以子窗口一创建就会以默认的 1280x720 在屏幕中央**真的显示出来**,内容区
全黑,然后消失,再由 Dart 侧按自己的尺寸 show 一次。

紧接着位置也不对。子窗口的调用序列是 `setFrame(0,0,w,h)` → `center()` → `show()`:

- `SetBounds()` 的 `gtk_window_move(0,0)` 在未映射的窗口上会置 `initial_pos_set`;
- `Center()` 只设了 `GTK_WIN_POS_CENTER`,而
  `gtk_window_compute_configure_request()` 里 `initial_pos_set` 的优先级更高,
  这个提示直接被忽略。

两条合起来就是用户看到的:"先显示一个黑屏窗口 → 窗口换个位置重新出来"。

### 改动

- `linux/flutter_window.cc`:删掉构造函数开头的 `gtk_widget_show()` 与末尾的
  `gtk_widget_hide()`。窗口保持未映射,直到 Dart 侧调 `show()`。
  **副作用(有意为之)**:未映射 = FlView 不 realize = 引擎推迟到 `Show()` 时才
  启动。本项目所有子窗口都走 `SubWindowManagerBase.createAndShow()`
  (create → setFrame → center → show),不受影响;如果以后有"只创建不显示"的
  用法,子窗口 Dart 要等到 show 之后才会跑。
- `linux/base_flutter_window.cc` 的 `Center()`:按窗口所在显示器(未映射时取主
  显示器)的 workarea 与当前尺寸算出居中坐标,直接 `gtk_window_move()`,映射前后
  行为一致。取不到尺寸/显示器时退回原来的 `GTK_WIN_POS_CENTER`。
  Wayland 下 `gtk_window_move` 无效,但那边 `GTK_WIN_POS_CENTER` 同样无效
  (位置由合成器决定),没有变差。

## 还没做:关窗后引擎/Dart 仍在跑

补丁 1 消掉的是"一个窗口两套 shell"。**正常那套 shell 在关窗时是否被干净销毁,
还没有实证**:`on_close_clicked` 里 `gtk_widget_destroy()` 同步销毁窗口 → FlView
析构 → `fl_view_dispose()` 先 `fl_engine_remove_view()`(隐式 view 的 RemoveView
在 embedder 侧直接返回 kInvalidArguments)、再 `g_clear_object(&self->engine)`。
理论上引擎此时就该 dispose + Shutdown,但另有 gdb 栈显示子窗口的 Dart 在窗口
(FlView)已经析构之后还在发 platform message(所以才有 window_manager 那个
`window=0x0` 崩溃)。补丁 1 落地后要重新确认:关掉子窗口,那三个引擎线程是不是
真的退出了。如果没退,再查谁多持了一份 FlEngine 引用。
