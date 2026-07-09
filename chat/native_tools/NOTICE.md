# 第三方开源软件声明

本应用的部分桌面端截图功能使用了 **flameshot**。

- 项目主页：https://github.com/flameshot-org/flameshot
- 许可证：GNU General Public License v3.0 or later（GPL-3.0-or-later）
- 完整许可证文本见同目录下的 `LICENSE.flameshot`

 flameshot 的源码位于 `../flameshot`（相对于本项目根目录的兄弟目录）。
 如果你需要获取 flameshot 的源码，也可以通过其 GitHub 仓库下载：
 https://github.com/flameshot-org/flameshot

---

## 说明

本应用将 flameshot 作为独立的可执行程序调用（通过命令行 `flameshot gui`），
并未将其代码链接或合并到本应用的 Flutter/Dart 代码中。

根据 GPL-3.0 的规定，我们向最终用户提供：

1. flameshot 的完整许可证文本（`LICENSE.flameshot`）。
2. 获取 flameshot 对应源码的途径（上述 GitHub 仓库或本地 `../flameshot` 目录）。

---

## Qt 依赖声明

 flameshot 基于 Qt6 构建。若你自行打包 Windows/macOS/Linux 二进制，
请确保同时遵守 Qt6 相关模块的许可证（通常为 LGPL-3.0 / GPL-3.0）。
具体需要保留 Qt 的许可证声明，并在必要时提供 Qt 源码获取方式。

（本文件仅作示例，具体合规方案请结合法务/合规审核。）
