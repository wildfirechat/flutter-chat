//
// Created by yangbin on 2022/1/11.
//

#include "flutter_window.h"

#include <iostream>

#include "include/desktop_multi_window/desktop_multi_window_plugin.h"
#include "desktop_multi_window_plugin_internal.h"

namespace {

WindowCreatedCallback _g_window_created_callback = nullptr;

}

gboolean on_close_clicked(GtkWidget *widget, GdkEvent *event, gpointer user_data) {
    // [PATCH] 原来在这里同步 gtk_widget_destroy():销毁发生在 delete-event
    // 回调栈内,此刻该窗口的帧时钟/绘制事件仍在途;而关窗后引擎不会立即停
    // (PATCHES.md "还没做:关窗后引擎/Dart 仍在跑"),僵尸引擎继续请求出帧,
    // 绘制落到正在销毁/已销毁的 GdkWindow 上,几秒后(有新的帧被调度时)在
    // gdk_window_end_draw_frame 里 SIGSEGV,整个进程连带主窗口崩掉。
    // 改为:先 hide —— 未映射窗口的帧时钟停止,不再调度新的绘制;destroy
    // 推迟到 idle,让当前事件处理与在途绘制走完、主循环回到干净状态再销毁。
    // 上游 macOS/Windows 实现同样是异步销毁,Linux 这条同步路径是独有的。
    gtk_widget_hide(widget);
    g_idle_add(+[](gpointer data) -> gboolean {
      gtk_widget_destroy(GTK_WIDGET(data));
      return G_SOURCE_REMOVE;
    }, widget);
    return TRUE;
}

FlutterWindow::FlutterWindow(
    int64_t id,
    const std::string &args,
    const std::shared_ptr<FlutterWindowCallback> &callback
) : callback_(callback), id_(id) {
  window_ = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_default_size(GTK_WINDOW(window_), 1280, 720);
  gtk_window_set_title(GTK_WINDOW(window_), "");
  gtk_window_set_position(GTK_WINDOW(window_), GTK_WIN_POS_CENTER);
  // [PATCH] 这里原本是 gtk_widget_show(window_),构造函数末尾再 hide 回去。
  // 于是子窗口一创建就会以 1280x720 在屏幕中间**真的显示出来**,而且一直显示到
  // 引擎起完(fl_view_new 里建引擎、跑 Dart 入口,几百毫秒),内容区全黑;
  // 之后被 hide,再由 Dart 侧按自己的尺寸/位置 show 一次 —— 用户看到的就是
  // "先弹一个黑窗、然后窗口换个位置重新出来"。见 PATCHES.md 补丁 2。
  // 不显示 = 不 realize = 引擎推迟到 Show() 时才启动,这正是想要的:
  // 窗口什么时候露面由 Dart 决定。

  g_signal_connect(G_OBJECT(window_), "delete-event", G_CALLBACK(on_close_clicked), NULL);
  g_signal_connect(window_, "destroy", G_CALLBACK(+[](GtkWidget *, gpointer arg) {
    auto *self = static_cast<FlutterWindow *>(arg);
    if (auto callback = self->callback_.lock()) {
      callback->OnWindowClose(self->id_);
      callback->OnWindowDestroy(self->id_);
    }
  }), this);

  g_autoptr(FlDartProject)
      project = fl_dart_project_new();
  const char *entrypoint_args[] = {"multi_window", g_strdup_printf("%ld", id_), args.c_str(), nullptr};
  fl_dart_project_set_dart_entrypoint_arguments(project, const_cast<char **>(entrypoint_args));

  // [PATCH] FlView 外面先套一层 GtkOverlay,必须赶在 fl_view_new 之前建好,
  // 且此后不能再改 FlView 的父节点。见 PATCHES.md 补丁 1:
  // webview_all_linux 要求 FlView 的父节点是 GtkOverlay,不是的话它会在运行时
  // 把 FlView 摘下来重挂进新建的 overlay;而 FlView 一旦 unrealize→realize,
  // fl_view.cc 的 realize_cb 会**再次**调用 fl_engine_start(),同一个 FlEngine
  // 上又起一套引擎 shell,旧 shell 的 ui/raster/io 三个线程永不退出、回调还指着
  // 这个 FlEngine —— 之后 100% 崩(见 PATCHES.md 里的三份栈)。
  // 主窗口 linux/runner/my_application.cc 早就这么干了,这里给子窗口补上。
  GtkWidget *overlay = gtk_overlay_new();
  gtk_widget_set_hexpand(overlay, TRUE);
  gtk_widget_set_vexpand(overlay, TRUE);
  gtk_widget_show(overlay);
  gtk_container_add(GTK_CONTAINER(window_), overlay);

  auto fl_view = fl_view_new(project);
  gtk_widget_set_hexpand(GTK_WIDGET(fl_view), TRUE);
  gtk_widget_set_vexpand(GTK_WIDGET(fl_view), TRUE);
  gtk_widget_show(GTK_WIDGET(fl_view));
  gtk_container_add(GTK_CONTAINER(overlay), GTK_WIDGET(fl_view));

  if (_g_window_created_callback) {
    _g_window_created_callback(FL_PLUGIN_REGISTRY(fl_view));
  }
  g_autoptr(FlPluginRegistrar)
      desktop_multi_window_registrar =
      fl_plugin_registry_get_registrar_for_plugin(FL_PLUGIN_REGISTRY(fl_view), "DesktopMultiWindowPlugin");
  desktop_multi_window_plugin_register_with_registrar_internal(desktop_multi_window_registrar);

  window_channel_ = WindowChannel::RegisterWithRegistrar(desktop_multi_window_registrar, id_);

  gtk_widget_grab_focus(GTK_WIDGET(fl_view));
  // [PATCH] 原来这里要 hide 掉构造函数开头 show 出来的窗口;现在压根没 show 过,
  // 窗口保持未映射,等 Dart 调 Show()。
}

WindowChannel *FlutterWindow::GetWindowChannel() {
  return window_channel_.get();
}

FlutterWindow::~FlutterWindow() = default;

void desktop_multi_window_plugin_set_window_created_callback(WindowCreatedCallback callback) {
  _g_window_created_callback = callback;
}