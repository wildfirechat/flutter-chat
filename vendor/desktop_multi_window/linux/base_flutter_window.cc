//
// Created by boyan on 2022/1/27.
//

#include "base_flutter_window.h"

void BaseFlutterWindow::Show() {
  auto window = GetWindow();
  if (!window) {
    return;
  }
  gtk_widget_show(GTK_WIDGET(window));
}

void BaseFlutterWindow::Hide() {
  auto window = GetWindow();
  if (!window) {
    return;
  }
  gtk_widget_hide(GTK_WIDGET(window));
}

void BaseFlutterWindow::SetBounds(double_t x, double_t y, double_t width, double_t height) {
  auto window = GetWindow();
  if (!window) {
    return;
  }
  gtk_window_move(GTK_WINDOW(window), static_cast<gint>(x), static_cast<gint>(y));
  gtk_window_resize(GTK_WINDOW(window), static_cast<gint>(width), static_cast<gint>(height));
}

void BaseFlutterWindow::SetTitle(const std::string &title) {
  auto window = GetWindow();
  if (!window) {
    return;
  }
  gtk_window_set_title(GTK_WINDOW(window), title.c_str());
}

void BaseFlutterWindow::Center() {
  auto window = GetWindow();
  if (!window) {
    return;
  }

  // [PATCH] 原实现只设 GTK_WIN_POS_CENTER,而这个提示只在窗口"第一次映射且没被
  // 显式 move 过"时才生效。子窗口的调用顺序恰好是 setFrame(0,0,w,h) → center()
  // → show():setFrame 里的 gtk_window_move 会置上 initial_pos_set,在
  // gtk_window_compute_configure_request 里优先级高于 GTK_WIN_POS_CENTER,
  // 于是窗口落在屏幕左上角或窗管随手摆的位置,肉眼看就是"自己挪了一下"。
  // 这里直接按显示器工作区算出居中坐标 move 过去,映射前后都是确定的。
  // 见 PATCHES.md 补丁 2。
  gint width = 0, height = 0;
  gtk_window_get_size(GTK_WINDOW(window), &width, &height);
  if (width <= 0 || height <= 0) {
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    return;
  }

  GdkScreen *screen = gtk_window_get_screen(GTK_WINDOW(window));
  GdkDisplay *display = screen != nullptr ? gdk_screen_get_display(screen)
                                          : gdk_display_get_default();
  if (display == nullptr) {
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    return;
  }

  // 未映射的窗口还没有 GdkWindow,拿不到"它在哪块屏",退回主显示器。
  GdkMonitor *monitor = nullptr;
  GdkWindow *gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_window != nullptr) {
    monitor = gdk_display_get_monitor_at_window(display, gdk_window);
  }
  if (monitor == nullptr) {
    monitor = gdk_display_get_primary_monitor(display);
  }
  if (monitor == nullptr) {
    monitor = gdk_display_get_monitor(display, 0);
  }
  if (monitor == nullptr) {
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    return;
  }

  GdkRectangle area;
  gdk_monitor_get_workarea(monitor, &area);
  gtk_window_move(GTK_WINDOW(window), area.x + (area.width - width) / 2,
                  area.y + (area.height - height) / 2);
}

void BaseFlutterWindow::Close() {
  auto window = GetWindow();
  if (!window) {
    return;
  }
  gtk_window_close(GTK_WINDOW(window));
}