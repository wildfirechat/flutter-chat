# 原生截图工具（flameshot）

本目录用于存放 Flutter 桌面端截图功能依赖的 `flameshot` 二进制(仅 Windows/Linux;
macOS 已改用系统原生 ScreenCaptureKit,不再需要 flameshot,见根目录 SCREENSHOT.md)。

## 分发

由于工具比较大，为方便开发者，采用压缩包的方式进行分发，未使用 git lfs
 开发、打包时，请将`linux.zip` 和`windows.zip`解压，解压后的目录结构要和后文的目录结构一致

## 目录结构

```text
native_tools/
├── windows/flameshot/             # bin/include/lib 安装树（官方 portable 包）
│   └── bin/                      # flameshot.exe + Qt6 DLL；打包时只取这里，include/lib 不分发
│   └── include/                  # include
│   └── lib/                      # lib
├── linux/flameshot/
│   ├── x86_64/squashfs-root/usr/ # AppImage --appimage-extract 原始产物
│   │   ├── bin/flameshot, bin/qt.conf
│   │   ├── lib/*.so*
│   │   └── plugins/platforms/、imageformats/ 等
│   └── arm64/squashfs-root/usr/  # 结构同上，目录名用 arm64（不是 aarch64）
```
> macOS 不再需要本目录:截图已改用 ScreenCaptureKit,`macos/flameshot.app` 已删除。

## 源码
https://github.com/heavyrain2012/flameshot

## 如何准备

> fork 项目，然后才能使用 github action 打包
> 已通过 git lfs 提交了 `native_tools.zip`，可直接删除`native_tools`目录，并有解压缩`native_tools.zip`使用预编译版本

### Windows

 通过github action 打包，并将 portable 包，按上面的目录结构放置

### Linux（支持多架构，目前支持 x86_64 和 arm64）

1. 通过 github action 打包，得到 AppImage 包
2. `./flameshot.AppImage --appimage-extract`解包，并按上面的目录结构放置

## 注意

- 实际二进制体积较大，建议通过 CI 构建后复制，或使用 git-lfs 管理。
- 本目录下已配置 `.gitignore`，默认不提交具体二进制，只提交说明文件。
- flameshot 主代码使用 GPL-3.0-or-later，分发时请保留其源码与许可证声明。
  同目录下已放置：
  - `LICENSE.flameshot`：flameshot 的 GPL-3.0 完整许可证文本。
  - `NOTICE.md`：第三方开源声明与源码获取方式。
- 打包时这些声明文件应随 flameshot 二进制一起放入最终产物。
