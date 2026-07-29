#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <flutter_webrtc/flutter_web_r_t_c_plugin.h>
#include <window_manager/window_manager_plugin.h>
#include <screen_retriever_windows/screen_retriever_windows_plugin_c_api.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>
#include <url_launcher_windows/url_launcher_windows.h>
#include <fvp/fvp_plugin_c_api.h>
#include <webview_all_windows/webview_windows_plugin.h>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
    auto* flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController*>(controller);
    auto* registry = flutter_view_controller->engine();
    FlutterWebRTCPluginRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("FlutterWebRTCPlugin"));
    WindowManagerPluginRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("WindowManagerPlugin"));
    // 子窗口无托盘用途,不注册 TrayManagerPlugin(托盘归主窗口独占,
    // 与 macOS / Linux 一致)。tray_manager 的 Windows 实现把 MethodChannel
    // 存在进程级全局 `channel` 里,子窗口注册会把主窗口那份顶掉:开着子窗口
    // 期间托盘点击/菜单事件全发到子窗口 isolate(那边没有 handler),子窗口
    // 关闭时析构函数再把它置空,主窗口托盘从此彻底失效。
    ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("ScreenRetrieverWindowsPluginCApi"));
    PermissionHandlerWindowsPluginRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
    // 媒体预览窗口:视频降级用系统播放器打开(找不到本地/远程文件等兜底场景)。
    UrlLauncherWindowsRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("UrlLauncherWindows"));
    // 子窗口也要显式注册 WebView 插件，否则独立引擎里的 WKWebView/EdgeWebView
    // 原生桥无法建立。
    WebviewWindowsPluginRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("WebviewWindowsPlugin"));
    // 媒体预览窗口:视频消息应用内预览，用第三方 fvp 包补的 video_player
    // Windows 后端(官方 video_player 在 Windows 上没有实现)。不注册的话
    // 子窗口里播视频会报 MissingPluginException(CreateRT)。
    FvpPluginCApiRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("FvpPluginCApi"));
    // 统一清单中其余插件(shared_preferences / path_provider /
    // device_info_plus / file_picker / sqflite)在本项目的
    // Windows 依赖集中没有原生实现(见 windows/flutter/
    // generated_plugin_registrant.cc,头文件不可链接),保留现状不注册。
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
