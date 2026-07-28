# 桌面端截图功能（flameshot）文档

> 适用平台：Windows / macOS / Linux  
> 技术方案：将 flameshot 作为独立可执行程序打包进 Flutter 应用，Dart 通过 `Process.run` 调用。  
> 源码位置：`../flameshot`（相对于本项目根目录的兄弟目录）。

---

## 1. 功能概述

在桌面端会话界面增加“截屏”按钮，点击后：

1. 隐藏 Flutter 窗口（仅 Windows/Linux；macOS 保持窗口可见）；
2. 调起 flameshot 的 GUI 选区截图；
3. 用户确认后 flameshot 生成 PNG；
4. Dart 读取截图文件路径；
5. 通过现有图片发送逻辑（`ConversationController.onPickImage`）作为图片消息发送；
6. 重新显示并聚焦 Flutter 窗口（仅 Windows/Linux）。

---

## 2. 技术方案：为什么不用 FFI / 动态库

flameshot 是一个完整的 **Qt6 GUI 应用**，包含自己的 `QApplication`、事件循环、全局快捷键、托盘、标注界面等。把它编译成动态库塞进 Flutter 进程会有以下问题：

- Qt 要求一个进程内只有一个 `QApplication`，且通常需要在主线程运行事件循环；Flutter 也持有主线程事件循环，二者会冲突。
- 截图是用户交互操作，持续几秒甚至更久，FFI 默认是同步调用，不适合这种“长交互”。
- 即使强行改成库，也需要剥离 `main()`、暴露 C API、处理 Qt 窗口生命周期，工程量和维护成本远高于直接调用进程。
- flameshot 是 GPL-3.0-or-later，动态链接进主程序更容易触发“衍生作品”条款；作为独立进程调用边界更清晰。

因此选择 **独立可执行文件 + `Process.run` 调用**。

---

## 3. 相关文件清单

```text
chat/
├── lib/
│   ├── utils/
│   │   └── screenshot_service.dart          # Dart 调用层
│   ├── conversation/
│   │   └── input_bar/
│   │       └── plugin_board.dart            # 移动端/面板入口（桌面端条件显示）
│   └── pc/
│       └── pc_message_input_bar.dart        # 桌面端工具栏入口
├── native_tools/
│   ├── README.md                            # 构建/放置说明
│   ├── NOTICE.md                            # 第三方开源声明
│   ├── LICENSE.flameshot                    # flameshot GPL-3.0 完整许可证
│   ├── windows/flameshot/                   # Windows 二进制 + Qt6 DLL
│   ├── linux/flameshot/<arch>/              # Linux 二进制 + Qt6 so（按架构分目录：x86_64、aarch64 等）
│   └── macos/flameshot.app/                 # macOS 完整 app bundle
├── windows/CMakeLists.txt                   # Windows 打包集成
├── linux/CMakeLists.txt                     # Linux 打包集成
└── macos/
    ├── Runner.xcodeproj/project.pbxproj     # macOS 打包集成（Copy flameshot.app）
    ├── Runner/Info.plist                    # NSScreenCaptureUsageDescription
    └── Runner/Release.entitlements          # macOS entitlement（已关闭 App Sandbox）
```

---

## 4. 构建与准备 flameshot

### 4.1 通用构建

```bash
cd ../flameshot
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
```

### 4.2 macOS

产物路径通常为 `../flameshot/build/src/flameshot.app`（小写开头）。用 `macdeployqt` 收集 Qt 依赖：

```bash
cd ../flameshot
macdeployqt build/src/flameshot.app
```

复制到项目：

```bash
cp -R ../flameshot/build/src/flameshot.app \
       chat/native_tools/macos/flameshot.app
```

> 注意：macOS 应用名是小写 `flameshot.app`，Dart 和 Xcode 脚本都按此路径查找。

### 4.3 Windows

```powershell
cd ..\flameshot
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --parallel
cd build\src
windeployqt --release flameshot.exe

# 把整个可运行目录复制到项目
xcopy /E /I /Y . ..\..\..\flutter-chat\chat\native_tools\windows\flameshot
```

### 4.4 Linux

```bash
cd ../flameshot
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel

# 用 linuxdeployqt / linuxdeploy 整理 Qt 依赖
# 然后按目标架构把 flameshot 二进制和依赖库放到 chat/native_tools/linux/flameshot/<arch>/
# 例如 x86_64、aarch64（也兼容无架构子目录的旧布局 linux/flameshot/）
```

---

## 5. 打包集成

### 5.1 Windows / Linux（CMake）

在 `chat/windows/CMakeLists.txt` 和 `chat/linux/CMakeLists.txt` 中已加入打包逻辑（以下为主要片段，略去警告分支）。

Windows：

```cmake
# native_tools 在应用根目录（chat/native_tools），不在 chat/windows、chat/linux 下
set(NATIVE_TOOLS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native_tools")

# 复制 flameshot 工具目录
set(FLAMESHOT_TOOL_DIR "${NATIVE_TOOLS_DIR}/windows/flameshot")
if(EXISTS "${FLAMESHOT_TOOL_DIR}/flameshot.exe")
  install(DIRECTORY "${FLAMESHOT_TOOL_DIR}/"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/flameshot"
    COMPONENT Runtime)
endif()
```

Linux 会按 `CMAKE_SYSTEM_PROCESSOR` 选择架构子目录，并兼容旧的无架构布局：

```cmake
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
  set(FLAMESHOT_ARCH "x86_64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
  set(FLAMESHOT_ARCH "aarch64")
# ...其余架构映射略
endif()

set(NATIVE_TOOLS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native_tools")
set(FLAMESHOT_TOOL_DIR "${NATIVE_TOOLS_DIR}/linux/flameshot/${FLAMESHOT_ARCH}")
set(FLAMESHOT_TOOL_DIR_LEGACY "${NATIVE_TOOLS_DIR}/linux/flameshot")
if(EXISTS "${FLAMESHOT_TOOL_DIR}/flameshot")
  install(DIRECTORY "${FLAMESHOT_TOOL_DIR}/"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/flameshot/${FLAMESHOT_ARCH}"
    COMPONENT Runtime)
elseif(EXISTS "${FLAMESHOT_TOOL_DIR_LEGACY}/flameshot")
  # 兼容旧的无架构子目录布局
  install(DIRECTORY "${FLAMESHOT_TOOL_DIR_LEGACY}/"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/flameshot"
    COMPONENT Runtime)
endif()
```

两个平台都会复制许可证声明：

```cmake
set(FLAMESHOT_LICENSE "${NATIVE_TOOLS_DIR}/LICENSE.flameshot")
set(FLAMESHOT_NOTICE "${NATIVE_TOOLS_DIR}/NOTICE.md")
if(EXISTS "${FLAMESHOT_LICENSE}")
  install(FILES "${FLAMESHOT_LICENSE}" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
endif()
if(EXISTS "${FLAMESHOT_NOTICE}")
  install(FILES "${FLAMESHOT_NOTICE}" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
endif()
```

执行 `flutter build windows` / `flutter build linux` 后，产物结构：

```text
build/windows/x64/runner/Release/      # 或 build/linux/x64/release/bundle/
├── wildfirechat.exe / wildfirechat
├── flameshot/
│   ├── flameshot.exe                  # Windows
│   ├── Qt6Core.dll / libQt6Core.so.6
│   └── x86_64/flameshot               # Linux：按架构子目录安装（旧布局则直接 flameshot/flameshot）
├── LICENSE.flameshot
└── NOTICE.md
```

### 5.2 macOS（Xcode）

在 `chat/macos/Runner.xcodeproj/project.pbxproj` 中新增了一个 `Copy flameshot.app` 的 Shell Script Build Phase：

```sh
set -e
SRC="${PROJECT_DIR}/../native_tools/macos/flameshot.app"
DST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/flameshot.app"
if [ -d "$SRC" ]; then
  rm -rf "$DST"
  cp -R "$SRC" "$DST"
else
  echo "warning: flameshot.app not found at $SRC"
fi

RESOURCES_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources"
for FILE in LICENSE.flameshot NOTICE.md; do
  SRC_FILE="${PROJECT_DIR}/../native_tools/$FILE"
  if [ -f "$SRC_FILE" ]; then
    cp "$SRC_FILE" "$RESOURCES_DIR/$FILE"
  fi
done
```

（实际脚本另有几行 `echo "[flameshot] ..."` 日志输出，此处略去。）

执行 `flutter build macos` 后产物结构：

```text
build/macos/Build/Products/Release/WildFireChat.app/Contents/Resources/
├── flameshot.app/
├── LICENSE.flameshot
└── NOTICE.md
```

---

## 6. Dart 调用流程

### 6.1 ScreenshotService API

文件：`chat/lib/utils/screenshot_service.dart`

主要方法：

```dart
// 是否已找到 flameshot 二进制
static Future<bool> get isAvailable;

// 调用 flameshot gui，返回 ScreenshotResult（path/error）；
// 用户取消时 path 与 error 均为 null
static Future<ScreenshotResult> captureToFile();

// 直接读回 PNG 字节（内部仍走临时文件）
static Future<Uint8List?> captureToBytes();
```

关键实现逻辑：

- 根据 `Platform.resolvedExecutable` 定位各平台二进制：
  - Windows：`flameshot/flameshot.exe`
  - Linux：`flameshot/<arch>/flameshot`（`<arch>` 由 `Abi.current()` 映射为 `x86_64`、`aarch64` 等；无架构子目录时回退到 `flameshot/flameshot`）
  - macOS：`../Resources/flameshot.app/Contents/MacOS/flameshot`
- 设置 `workingDirectory` 为 flameshot 目录，保证 Windows 能找到同目录 DLL。
- Linux 设置 `LD_LIBRARY_PATH`，Windows 设置 `PATH`；macOS 不注入额外环境变量。
- 调用前 `windowManager.hide()`，调用后 `windowManager.show()` + `focus()`——仅 Windows/Linux；macOS 保持窗口可见（隐藏主窗口可能导致子进程无法获得屏幕录制权限或窗口焦点）。

### 6.2 UI 入口

#### 桌面端工具栏

文件：`chat/lib/pc/pc_message_input_bar.dart`

新增按钮：

```dart
_ToolbarButton(
  icon: Icons.cut,
  tooltip: l10n.screenshotTool,
  onTap: () => _captureScreenshot(conversationController, controller),
),
```

对应方法：

```dart
Future<void> _captureScreenshot(
    ConversationController conversationController,
    MessageInputBarController controller) async {
  final available = await ScreenshotService.isAvailable;
  if (!available) {
    if (mounted) {
      showToast(msg: AppLocalizations.of(context)!.screenshotToolNotAvailable);
    }
    return;
  }
  final result = await ScreenshotService.captureToFile();
  if (result.success) {
    conversationController.onPickImage(controller.conversation, result.path!);
  } else if (result.error != null && mounted) {
    showToast(msg: result.error!);
  }
}
```

#### 移动端/插件面板

文件：`chat/lib/conversation/input_bar/plugin_board.dart`

桌面端条件下增加 `screenshot` 项（`WfcPlatform.isNativeDesktop` 控制），点击后同样走 `ScreenshotService.captureToFile()`。

### 6.3 发送图片消息

截图成功后，直接复用现有逻辑：

```dart
conversationController.onPickImage(conversation, path);
```

该方法会构造 `ImageMessageContent`，设置 `localPath`，最终调用：

```dart
Imclient.sendMediaMessage(conversation, imageContent, ...);
```

---

## 7. 权限与系统声明

### 7.1 macOS

- 已在 `chat/macos/Runner/Info.plist` 添加：

  ```xml
  <key>NSScreenCaptureUsageDescription</key>
  <string>截屏功能需要录制屏幕内容</string>
  ```

- **App Sandbox 已关闭**：macOS 的 App Sandbox 会阻止 flameshot（子进程）访问屏幕录制/窗口服务，导致 flameshot 初始化失败并立即退出。因此 `chat/macos/Runner/Release.entitlements` 和 `DebugProfile.entitlements` 中已移除 `com.apple.security.app-sandbox`。
- 首次调用 flameshot 截图时，系统会弹出“屏幕录制”权限提示，用户授权后才能正常截图。
- **重要**：关闭沙盒后**无法直接上架 Mac App Store**。如必须走 App Store，需要改用原生 `ScreenCaptureKit` 方案，而不是 flameshot。

### 7.2 Windows

- 普通 GDI 截图通常不需要额外权限。
- 分发时注意代码签名，避免 SmartScreen 拦截。

### 7.3 Linux

- X11 环境下直接可用。
- Wayland 需要 `xdg-desktop-portal` + `grim`， flameshot 对 Wayland 支持是实验性的，需在目标桌面环境实测。

---

## 8. 许可证合规

### 8.1 flameshot（GPL-3.0-or-later）

- 已放置完整许可证：`chat/native_tools/LICENSE.flameshot`
- 已放置声明文件：`chat/native_tools/NOTICE.md`
- 打包脚本已确保 LICENSE / NOTICE 随二进制一起分发。

GPL 分发二进制时的核心义务：

1. 向接收者提供完整 GPL 许可证文本。
2. 提供“对应源码”（Corresponding Source），即 flameshot 的源码。你们可以通过以下方式满足：
   - 把本地 `../flameshot` 源码一并打包；
   - 或在 `NOTICE.md` 中提供可长期访问的源码下载链接（如 GitHub Release、CDN）。
3. 保留 flameshot 源码和二进制中的版权声明。

### 8.2 Qt6 依赖

 flameshot 基于 Qt6。使用 `windeployqt` / `macdeployqt` / `linuxdeployqt` 打包时会带上 Qt6 动态库。Qt6 核心模块通常为 **LGPL-3.0 / GPL-3.0**，需要：

- 保留 Qt 的许可证声明；
- 在必要时提供 Qt 源码获取方式；
- 使用动态链接（不要静态链接 LGPL 模块），确保用户可替换 Qt 动态库。

> **免责声明**：本文档是工程层面的合规准备，正式对外分发前请让法务或合规同事审核。

---

## 9. 测试验证

### 9.1 macOS

```bash
cd chat
flutter build macos
ls build/macos/Build/Products/Release/WildFireChat.app/Contents/Resources/flameshot.app
ls build/macos/Build/Products/Release/WildFireChat.app/Contents/Resources/LICENSE.flameshot
```

运行后打开一个会话，点击工具栏“截屏”图标，应弹出 flameshot 选区，确认后图片作为消息发送。

### 9.2 Windows

```bash
cd chat
flutter build windows
ls build/windows/x64/runner/Release/flameshot/flameshot.exe
ls build/windows/x64/runner/Release/LICENSE.flameshot
```

### 9.3 Linux

```bash
cd chat
flutter build linux
ls build/linux/x64/release/bundle/flameshot/x86_64/flameshot
ls build/linux/x64/release/bundle/LICENSE.flameshot
```

（若使用的是无架构子目录的旧布局，则路径为 `flameshot/flameshot`。）

---

## 10. 常见问题

### Q1：点击截屏提示“截屏工具不可用”

检查对应平台的 flameshot 二进制是否已正确放入 `chat/native_tools/<platform>/`：

- macOS：`native_tools/macos/flameshot.app/Contents/MacOS/flameshot`
- Windows：`native_tools/windows/flameshot/flameshot.exe`
- Linux：`native_tools/linux/flameshot/<arch>/flameshot`（`<arch>` 如 `x86_64`、`aarch64`；也兼容旧布局 `native_tools/linux/flameshot/flameshot`）

### Q2：macOS 上 flameshot 弹不出来

- 检查系统是否已授权“屏幕录制”权限（系统设置 → 隐私与安全性 → 屏幕录制）。
- 确认 `Info.plist` 中已添加 `NSScreenCaptureUsageDescription`。

### Q3：Windows 上提示找不到 Qt DLL

确认 `windeployqt` 已正确运行，且所有 DLL 与 `flameshot.exe` 在同一目录 `native_tools/windows/flameshot/`。

### Q4：Linux Wayland 下无法截图

 flameshot 对 Wayland 支持有限，确保已安装：

```bash
sudo apt install xdg-desktop-portal grim
```

并在 X11 会话或兼容的 Wayland compositor 下测试。

---

## 11. 参考资料

- [flameshot GitHub](https://github.com/flameshot-org/flameshot)
- [Flameshot Command Line Options](https://flameshot.org/docs/advanced/commandline-options/)
- [Flameshot License Overview](https://flameshot.org/docs/overview/overview/)
- [GNU GPL v3](https://www.gnu.org/licenses/gpl-3.0.html)
