# 桌面端截图功能文档

> 适用平台：Windows / macOS / Linux  
> 技术方案：**macOS 使用苹果原生 ScreenCaptureKit**（自研覆盖窗 + 标注编辑器，见 `chat/macos/Runner/Screenshot/`）；Windows / Linux 将 flameshot 作为独立可执行程序打包，Dart 通过 `Process.run` 调用。  
> flameshot 源码位置：`../flameshot`（相对于本项目根目录的兄弟目录）。

---

## 1. 功能概述

在桌面端会话界面增加“截屏”按钮，按钮旁有下拉箭头，提供两种模式：

在桌面端会话界面增加“截屏”按钮，按钮旁有紧贴的下拉箭头（对齐微信 PC），菜单提供两种模式：

- **截屏（默认）**：本 App 窗口出现在截图画面里——macOS 不排除本 App 窗口；Windows/Linux 不隐藏窗口；
- **隐藏窗口截图**：macOS 用 ScreenCaptureKit 的 `excludingWindows` 直接排除本 App 全部窗口（无需真的隐藏，无动画）；Windows/Linux 用 `windowManager.hide()` 隐藏主窗口（orderOut，瞬时无动画），截图完成（或取消/异常）后 `show()` + `focus()` 恢复。

**macOS（ScreenCaptureKit）流程**：

1. Dart 经 `chat/screenshot` MethodChannel 调起原生截图（参数 `excludeSelf` 对应上述模式）；
2. 原生侧用 ScreenCaptureKit 逐屏截图；
3. 每个显示器弹出一个全屏覆盖窗：拖拽框选、标注（矩形/箭头/画笔/文字/马赛克）、撤销重做、复制、保存、取消（Esc）；
4. 确认后选区裁剪 + 标注拍平为 PNG 写入临时目录，路径回传 Dart；
5. 通过现有图片发送逻辑（`ConversationController.onPickImage`）作为图片消息发送。

**Windows / Linux（flameshot）流程**：

1. 调起 flameshot 的 GUI 选区截图（隐藏窗口模式先 hide 主窗口）；
2. 用户确认后 flameshot 生成 PNG；
3. Dart 读取截图文件路径；
4. 通过现有图片发送逻辑（`ConversationController.onPickImage`）作为图片消息发送；
5. 若为隐藏窗口截图，恢复并聚焦 Flutter 窗口。

> 注：Windows/Linux 的隐藏窗口模式统一用 `windowManager.hide()` 而不是最小化——hide（orderOut）瞬间完成没有动画；macOS 的 genie 最小化动画只能系统级关闭，应用无法控制。flameshot 是独立进程、自己持有屏幕录制权限，主窗口隐藏不影响它。

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
│   ├── windows/flameshot/bin/                # Windows 二进制 + Qt6 DLL（bin/include/lib 安装树）
│   └── linux/flameshot/<arch>/squashfs-root/usr/  # AppImage 解包产物（按架构分目录：x86_64、arm64）
├── windows/CMakeLists.txt                   # Windows 打包集成
├── linux/CMakeLists.txt                     # Linux 打包集成
└── macos/
    ├── Runner/Screenshot/                   # macOS ScreenCaptureKit 截图(自研)
    │   ├── ScreenCaptureManager.swift       #   权限/逐屏截图/拍平/chat/screenshot 通道
    │   ├── CaptureOverlayWindow.swift       #   全屏覆盖窗(每显示器一个)
    │   ├── CaptureOverlayView.swift         #   框选/标注/工具条交互
    │   └── Annotations.swift                #   标注模型与绘制
    ├── Runner.xcodeproj/project.pbxproj     # macOS 工程(Screenshot 源文件已加入 Runner target)
    ├── Runner/Info.plist                    # NSScreenCaptureUsageDescription
    └── Runner/Release.entitlements          # macOS entitlement(已开启 App Sandbox,见 §7.1)
```

> 注：macOS 的 `Copy flameshot.app` 构建阶段与 `native_tools/macos/flameshot.app`
> 已随 ScreenCaptureKit 改造一并移除；Windows/Linux 的 flameshot 不受影响。

---

## 4. 构建与准备 flameshot

### 4.1 通用构建

```bash
cd ../flameshot
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
```

### 4.2 macOS

macOS 已改用系统原生 **ScreenCaptureKit**，不再需要 flameshot，无构建准备步骤。
旧的 flameshot.app 打包流程（`macdeployqt` + 复制到 `native_tools/macos/`）仅作为
历史参考保留在 Git 记录中。

### 4.3 Windows

布局固定为 `bin/include/lib` 安装树（官方 portable 包 / `cmake --install` 产物），
`flameshot.exe` 在 `bin/` 下：

```powershell
cd ..\flameshot
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --parallel
cmake --install build --prefix install
cd install\bin
windeployqt --release flameshot.exe

# 把整个安装树复制到项目（bin/include/lib 一起放进去即可，
# 打包时只会取用 bin/ 下的内容）
xcopy /E /I /Y ..\.. ..\..\..\..\flutter-chat\chat\native_tools\windows\flameshot
```

最终应有 `native_tools/windows/flameshot/bin/flameshot.exe`。

### 4.4 Linux

用 `linuxdeploy` + `linuxdeploy-plugin-qt` 打出 AppImage（会自动生成 `qt.conf`
和 `plugins/` 目录），再原样解包，不需要自己拼目录：

```bash
cd ../flameshot
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel

# 用 linuxdeploy + linuxdeploy-plugin-qt 打出 flameshot-<arch>.AppImage
# 然后原地解包：
chmod +x flameshot-x86_64.AppImage
./flameshot-x86_64.AppImage --appimage-extract
# 产物在 squashfs-root/，整个目录搬到（不同架构分别构建、分别放）：
# chat/native_tools/linux/flameshot/x86_64/squashfs-root/
# chat/native_tools/linux/flameshot/arm64/squashfs-root/
```

CMake 会根据 `CMAKE_SYSTEM_PROCESSOR` 自动选择 `x86_64`、`arm64` 子目录（注意目录名用的是
`arm64`，不是 `uname -m` 的 `aarch64`）；Dart 层也按同样的名字在运行时定位对应架构的二进制。
项目本身不支持交叉编译，arm64 版本需要在 arm64 机器上本地构建。

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
# 布局是 bin/include/lib 安装树（cmake --install / 官方 portable 包）；
# 只取 bin/ 下的运行时文件，include/lib 是链接用的开发产物不分发。
if(EXISTS "${FLAMESHOT_TOOL_DIR}/bin/flameshot.exe")
  install(DIRECTORY "${FLAMESHOT_TOOL_DIR}/bin/"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/flameshot"
    COMPONENT Runtime)
endif()
```

Linux 会按 `CMAKE_SYSTEM_PROCESSOR` 选择架构子目录（目录名用 `arm64`，不是 `uname -m`
的 `aarch64`），并整体搬运 AppImage 解包产物里的 `squashfs-root/usr/`（保留
`bin/`、`lib/`、`plugins/` 的相对关系，`qt.conf` 靠这个关系找 Qt 平台插件）：

```cmake
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
  set(FLAMESHOT_ARCH "x86_64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
  set(FLAMESHOT_ARCH "arm64")
# ...其余架构映射略
endif()

set(NATIVE_TOOLS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native_tools")
set(FLAMESHOT_TOOL_DIR "${NATIVE_TOOLS_DIR}/linux/flameshot/${FLAMESHOT_ARCH}/squashfs-root/usr")
if(EXISTS "${FLAMESHOT_TOOL_DIR}/bin/flameshot")
  install(DIRECTORY "${FLAMESHOT_TOOL_DIR}/"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/flameshot/${FLAMESHOT_ARCH}"
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
│   ├── flameshot.exe, Qt6Core.dll, …   # Windows：拍平后的 bin/ 内容
│   └── x86_64/ 或 arm64/               # Linux：按架构子目录安装
│       ├── bin/flameshot, bin/qt.conf
│       ├── lib/libQt6Core.so.6, …
│       └── plugins/platforms/…
├── LICENSE.flameshot
└── NOTICE.md
```

### 5.2 macOS（ScreenCaptureKit）

macOS 无第三方打包集成。截图实现位于 `chat/macos/Runner/Screenshot/`：

- `ScreenCaptureManager.swift`：注册 `chat/screenshot` MethodChannel（在 `MainFlutterWindow.swift` 的 `awakeFromNib` 中注册）；检查屏幕录制权限（`CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`）；用 `SCShareableContent` + `SCContentFilter(display:excludingWindows:)` 逐屏截图（排除本 App 全部窗口）；确认后把选区裁剪 + 标注拍平为 PNG 写入 `NSTemporaryDirectory()` 并回传路径；复制走 `NSPasteboard`。
- `CaptureOverlayWindow.swift`：无边框、`.screenSaver` 层级、`canJoinAllSpaces` 的全屏覆盖窗，每个显示器一个。
- `CaptureOverlayView.swift`：框选（创建/移动/8 手柄调整）、标注编辑（矩形/箭头/画笔/文字/马赛克）、撤销重做、悬浮工具条（SF Symbols 图标 + 6 色色板）、Esc 取消、Enter/双击确认。
- `Annotations.swift`：标注数据模型与绘制；马赛克用 `CIPixellate` 离线渲染。

Dart 侧 `ScreenshotService.captureToFile` 在 macOS 上直接调 `chat/screenshot` 通道，不再经过 flameshot 进程。

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
  - Windows：`flameshot/flameshot.exe`（打包阶段由 CMake 从
    `native_tools/windows/flameshot/bin/`铺平安装，Dart 侧看到的始终是扁平布局，
    无需关心 native_tools 里 bin/include/lib 的原始目录形态）
  - Linux：`flameshot/<arch>/bin/flameshot`（`<arch>` 由 `Abi.current()` 映射为
    `x86_64`、`arm64`；bin/ 下的 `qt.conf` 靠与兄弟目录 `plugins/` 的相对关系定位
    Qt 平台插件，因此不能拍平，`_toolDir` 固定指到 `bin/`）
  - macOS：`../Resources/flameshot.app/Contents/MacOS/flameshot`
- 设置 `workingDirectory` 为 flameshot 目录，保证 Windows 能找到同目录 DLL。
- Linux 设置 `LD_LIBRARY_PATH` 指向 `bin/` 的兄弟目录 `lib/`，Windows 设置 `PATH`；
  macOS 不注入额外环境变量。
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

- 截图改用 ScreenCaptureKit 后，截图功能在 App Sandbox 下正常工作（ScreenCaptureKit 是苹果官方受沙盒支持的截图方式，权限经系统弹窗授予）。首次截图时系统弹出“屏幕录制”权限提示，用户授权后即可使用；拒绝时 Dart 侧 toast 引导到 系统设置 → 隐私与安全性 → 屏幕录制 开启。
- `Release.entitlements` 已开启 `com.apple.security.app-sandbox`（发布版），网络/麦克风/摄像头/用户选择文件等所需 entitlement 均已配置；`DebugProfile.entitlements` 未开启，便于开发调试。

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
open build/macos/Build/Products/Release/WildFireChat.app
```

运行后打开一个会话，点击工具栏“截屏”图标：首次使用会弹“屏幕录制”权限，授权后
每个显示器出现全屏覆盖窗；拖拽框选 → （可选）标注 → 点“保存”或 Enter/双击，
图片作为消息发送；Esc 取消不发送。

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
ls build/linux/x64/release/bundle/flameshot/x86_64/bin/flameshot
ls build/linux/x64/release/bundle/flameshot/x86_64/plugins/platforms/
ls build/linux/x64/release/bundle/LICENSE.flameshot
```

---

## 10. 常见问题

### Q1：点击截屏提示“截屏工具不可用”

- macOS：截图是系统原生能力（ScreenCaptureKit），不涉及二进制检查；提示不可用多为原生通道未注册，请用完整 `flutter build macos` 产物运行。
- Windows：`native_tools/windows/flameshot/bin/flameshot.exe`
- Linux：`native_tools/linux/flameshot/<arch>/squashfs-root/usr/bin/flameshot`（`<arch>` 如 `x86_64`、`arm64`）

### Q2：macOS 上截图没有反应或提示无权限

- 检查系统是否已授权“屏幕录制”权限（系统设置 → 隐私与安全性 → 屏幕录制），授权后重启 App。
- 确认 `Info.plist` 中已添加 `NSScreenCaptureUsageDescription`。
- 覆盖窗弹不出时，检查是否有其他 App 占用了屏保层级窗口或处于特殊全屏 Space。

### Q3：Windows 上提示找不到 Qt DLL

确认 `windeployqt` 已正确运行，且所有 DLL 与 `flameshot.exe` 在同一目录 `native_tools/windows/flameshot/bin/`。

### Q4：Linux Wayland 下无法截图

 flameshot 对 Wayland 支持有限，确保已安装：

```bash
sudo apt install xdg-desktop-portal grim
```

并在 X11 会话或兼容的 Wayland compositor 下测试。

---

## 11. 参考资料

- [ScreenCaptureKit（Apple Developer）](https://developer.apple.com/documentation/screencapturekit)
- [flameshot GitHub](https://github.com/flameshot-org/flameshot)（Windows/Linux 方案）
- [Flameshot Command Line Options](https://flameshot.org/docs/advanced/commandline-options/)
- [Flameshot License Overview](https://flameshot.org/docs/overview/overview/)
- [GNU GPL v3](https://www.gnu.org/licenses/gpl-3.0.html)
