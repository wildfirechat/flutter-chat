# PC 端 UI 适配实施计划

> 基于 `PC_UI_ADAPTATION_PLAN.md` 与当前代码盘点后的待修改清单。
> 生成时间：2026-07-07

---

## 一、已落地基础（不再列为待修改）

- 入口平台分流：`main.dart` → `PCHome` / `HomeTabBar`
- 三栏 Shell：`chat/lib/pc/pc_home.dart`
- 会话/联系人列表回调注入
- 会话页拆分为 `ConversationPane` / `PcConversationPane`
- 桌面输入栏基础形态：`PcMessageInputBar`
- 消息右键菜单、Hover、滚动条、`PcTheme`
- 中栏搜索浮层：`PcSearchView`

---

## 二、P0 — 核心闭环（已完成）

| 序号 | 界面/模块 | 完成内容 | 涉及文件 |
|------|-----------|-----------|----------|
| 1 | **PC 端二维码登录** | 已实现。桌面端默认进入二维码登录页，展示 `wildfirechat://pcsession/{token}` 二维码并轮询 `/session_login/{token}`；成功后保存 userId/token 并连接 IM；同时保留手机号登录作为 fallback。 | 新增 `chat/lib/pc/pc_qr_login_screen.dart`<br>修改 `chat/lib/app_server.dart`<br>修改 `chat/lib/main.dart` |
| 2 | **输入栏：粘贴/拖拽文件** | 已实现。会话区域支持拖拽文件/图片发送；桌面输入栏支持 Ctrl/Cmd+V 粘贴图片发送。 | 修改 `chat/lib/conversation/conversation_pane.dart`<br>修改 `chat/lib/pc/pc_message_input_bar.dart`<br>新增依赖 `desktop_drop`、`super_clipboard`、`cross_file` |
| 3 | **输入栏：音视频入口门控** | 已实现。桌面端隐藏语音/视频通话按钮（rtckit 桌面无实现）。 | 修改 `chat/lib/pc/pc_message_input_bar.dart` |
| 4 | **视频消息桌面降级** | 已实现。桌面端点击视频消息用系统播放器打开；预览页中视频播放器也改为提示"用系统播放器打开"。 | 修改 `chat/lib/conversation/conversation_controller.dart`<br>修改 `chat/lib/conversation/mm_preview_view.dart` |
| 5 | **扫一扫入口隐藏** | 已实现。`PluginBoard` 桌面端隐藏 camera/call/location，album 改用 file_picker；手机端首页扫一扫入口自然不进入桌面 Shell。 | 修改 `chat/lib/conversation/input_bar/plugin_board.dart` |
| 6 | **Toast 抽象** | 已实现。新增 `showToast()` 工具类：移动端走 fluttertoast，桌面端使用 Overlay 自绘；第一批已替换核心文件（conversation_controller / conversation_pane / plugin_board / home / pc_home / pc_login_screen / login_screen），剩余 ~130 处可继续分批替换。 | 新增 `chat/lib/utils/show_toast.dart`<br>修改 `chat/lib/main.dart`（注入 navigatorKey）<br>分批替换 `Fluttertoast.showToast` |

---

## 三、P1 — 系统集成

| 序号 | 界面/模块 | 需要做什么 | 涉及文件 |
|------|-----------|-----------|----------|
| 7 | **窗口管理** | 新增 `window_manager`：最小尺寸 ~900×640、启动尺寸/位置记忆、最大化、关闭事件拦截 | 修改 `chat/pubspec.yaml`<br>修改 `chat/lib/main.dart`<br>可选修改 native runner（macOS/Windows/Linux） |
| 8 | **托盘管理** | 新增 `tray_manager`：关闭进托盘、托盘菜单、点击托盘显示窗口、未读闪烁 | 新增依赖 `tray_manager`<br>新增 `chat/lib/pc/pc_tray_manager.dart`<br>修改 `chat/lib/main.dart` |
| 9 | **桌面通知** | 统一 `WfcNotificationManager` 平台策略：macOS/Linux 用 `flutter_local_notifications`，Windows 补 `local_notifier`；点击通知激活窗口并跳转会话 | 修改 `chat/lib/wfc_notification_manager.dart`<br>修改 `chat/lib/main.dart`（接收 payload 并 `_openConversation`）<br>Windows 新增通知插件 |
| 10 | **单实例** | 二次启动只激活已有窗口 | 新增依赖 `windows_single_instance`<br>修改 `chat/windows/runner/main.cpp`<br>macOS/Linux 各自方案 |
| 11 | **Dock/任务栏 badge** | 收到消息时更新未读 badge | 修改 `chat/lib/main.dart`<br>macOS 原生 badge / Windows overlay icon |

---

## 四、P2/P3 — 补全与右栏化

| 序号 | 界面/模块 | 需要做什么 | 涉及文件 |
|------|-----------|-----------|----------|
| 12 | **设置页右栏化** | `MeTab` 中"设置/收藏/文件/关于"等子页面目前在桌面端会全屏 push，应改为在右栏打开 | 修改 `chat/lib/settings/me_tab.dart`<br>相关设置子页改为可嵌入 Pane |
| 13 | **联系人/群管理页右栏化** | 用户资料、群信息、群成员、聊天记录搜索等二级页，在桌面端应纳入右栏嵌套 Navigator | 修改 `chat/lib/contact/` 下用户资料页<br>修改 `chat/lib/conversation/group_info/` 相关页面 |
| 14 | **新的朋友入口** | PC 联系人列表中"新的朋友"缺少"查看全部"入口进入 `FriendRequestPage` | 修改 `chat/lib/pc/pc_contact_list.dart:145-151` |
| 15 | **全局搜索** | 当前搜索浮层结果通过回调打开；可补全搜索 UI 与历史记录 | `chat/lib/pc/pc_search_view.dart` |
| 16 | **媒体预览大图** | 图片/视频预览在桌面端应支持更大窗口、缩放、系统播放器兜底 | `chat/lib/conversation/mm_preview_view.dart` |
| 17 | **手机端联动** | "PC 已登录"横幅、手机端静音开关、`kickoffPCClient` 退出 PC 登录等闭环 | 修改 `chat/lib/home/conversation_list_widget.dart` 相关横幅逻辑 |
| 18 | **开机自启** | 可选 P2 | 新增依赖 `launch_at_startup` |

---

## 五、建议推进顺序

1. **先补 P0 闭环**：二维码登录、粘贴/拖拽、音视频按钮门控、视频消息降级、Toast 抽象。这几项做完后，PC 端基本可用。
2. **再做 P1 系统集成**：窗口/托盘/通知/badge/单实例，让 PC 端像个真正的桌面 IM。
3. **最后 P2/P3 右栏化与细节**：设置页、联系人/群页、全局搜索、媒体预览等，把体验补齐。
