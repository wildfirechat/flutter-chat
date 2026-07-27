#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// 单实例互斥量名称
const wchar_t* kSingleInstanceMutexName = L"WildfireChatFlutterDesktop";

// 主窗口标题。Dart 侧把标题栏设成 hidden(见 pc_window_manager.dart),但这个值仍会
// 出现在任务栏和 Alt-Tab 里,也是下面 FindWindowW 找已有实例的依据 —— 两处必须用
// 同一个常量,改了标题却忘了改查找串,单实例激活就会静默失效。
const wchar_t* kMainWindowTitle = L"野火IM";

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // 尝试创建单实例互斥量
  HANDLE mutex = ::CreateMutexW(nullptr, FALSE, kSingleInstanceMutexName);
  if (mutex == nullptr || ::GetLastError() == ERROR_ALREADY_EXISTS) {
    // 已有实例运行,尝试激活已有窗口后退出
    HWND existing = ::FindWindowW(nullptr, kMainWindowTitle);
    if (existing != nullptr) {
      ::ShowWindow(existing, SW_RESTORE);
      ::SetForegroundWindow(existing);
    }
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kMainWindowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::ReleaseMutex(mutex);
  ::CloseHandle(mutex);

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
