# 原生截图工具（flameshot）

本目录用于存放 Flutter 桌面端截图功能依赖的 `flameshot` 二进制。

## 目录结构

```text
native_tools/
├── windows/flameshot/            # Windows: flameshot.exe + Qt6 DLL
├── linux/flameshot/
│   ├── x86_64/                   # Linux x86_64
│   ├── aarch64/                  # Linux ARM64
│   └── ...                       # 其他架构
└── macos/flameshot.app           # macOS: 完整的 flameshot.app 包
```

## 如何准备

 flameshot 源码在 `../flameshot`（项目根目录的兄弟目录）。

### macOS（已有编译包）

把编译好的 `flameshot.app` 直接复制到本目录：

```bash
cp -R ../flameshot/build/src/flameshot.app chat/native_tools/macos/flameshot.app
```

### Windows

在 flameshot 源码目录构建并收集依赖：

```powershell
cd ..\flameshot
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --parallel
cd build\src
windeployqt --release flameshot.exe
xcopy /E /I /Y . ..\..\..\flutter-chat\chat\native_tools\windows\flameshot
```

### Linux（支持多架构）

需要根据目标架构分别存放。例如 x86_64：

```bash
cd ../flameshot
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel

# 用 linuxdeployqt 或手动整理 Qt 依赖
# 最终放到 chat/native_tools/linux/flameshot/x86_64/
```

CMake 会根据 `CMAKE_SYSTEM_PROCESSOR` 自动选择 `x86_64`、`aarch64` 等子目录；
Dart 层也会根据 `Abi.current()` 在运行时定位对应架构的二进制。

## 注意

- 实际二进制体积较大，建议通过 CI 构建后复制，或使用 git-lfs 管理。
- 本目录下已配置 `.gitignore`，默认不提交具体二进制，只提交说明文件。
- flameshot 主代码使用 GPL-3.0-or-later，分发时请保留其源码与许可证声明。
  同目录下已放置：
  - `LICENSE.flameshot`：flameshot 的 GPL-3.0 完整许可证文本。
  - `NOTICE.md`：第三方开源声明与源码获取方式。
- 打包时这些声明文件应随 flameshot 二进制一起放入最终产物。
