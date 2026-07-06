# PC 端 UI 适配方案

> 前置状态:桌面端 FFI 单实现已落地(见 DESKTOP_REFACTOR_PLAN.md / DESKTOP_STATUS.md 6.5),
> Windows / macOS / Linux 均已能构建运行。SDK 能力层已就绪,本文档只讨论 **UI/UX 与系统集成适配**。
> 本文档为方案讨论稿,未开始实施。

---

## 0. 现状盘点(实测依据)

| 项 | 现状 | 证据 |
|----|------|------|
| 整体形态 | 纯手机 UI:底部 `CupertinoTabBar` 五 tab + 全屏页面栈 | `chat/lib/home/home.dart` |
| 导航耦合 | 38 个文件、105 处 `Navigator.push(MaterialPageRoute)`,页面跳转硬编码在叶子组件内 | grep 统计 |
| `chat/lib/pc/` | 只有 `pc_login_screen.dart`——**手机侧**扫码确认 PC 登录的页面,不是桌面 UI | 目录只此一文件 |
| 登录 | 手机号 + 验证码(`login_screen.dart`);app server 已有 `scan_pc`/`confirm_pc`/`cancel_pc`(手机侧三件套) | `chat/lib/app_server.dart:233-273` |
| 输入栏 | 手机形态:语音按钮、表情板、插件板;`onSubmitted` 发送已有,但无 Shift+Enter 换行、无粘贴图片、无拖拽 | `chat/lib/conversation/input_bar/` |
| 消息操作 | 长按弹菜单(手机习惯),无右键 | `chat/lib/conversation/message_cell.dart` |
| 通知 | 仅 Android(`wfc_notification_manager.dart` 硬编码平台判断) | DESKTOP_STATUS 3.3 |
| 音视频 | rtckit 桌面端无实现,已平台门控 | DESKTOP_STATUS 3.1/3.2 |
| 窗口管理 | 无:窗口尺寸、托盘、单实例、badge 全部缺失 | — |

## 1. 核心决策:桌面 UI 架构三选一

### 方案 A:响应式改造现有页面(breakpoint 自适应)

用 `LayoutBuilder`/`flutter_adaptive_scaffold` 思路,宽屏时 master-detail。
**不推荐**:105 处 `Navigator.push` 每一处都要区分"全屏 push 还是右栏替换",
改造面即全部 38 个文件,且手机端回归风险最大。响应式的收益(平板/折叠屏)
当前不是需求。

### 方案 B:独立桌面 Shell + 复用叶子组件(推荐)

- 入口按平台分流:`main.dart` 里 `isDesktop`(Windows/macOS/Linux)→ `PCHome`,否则现有 `HomeTabBar`。移动端代码路径**零改动**。
- `chat/lib/pc/` 下建桌面 Shell:经典三栏(参照微信 PC / 野火官方 PC 端):
  - 左侧 60~72px 侧栏:头像、消息/联系人/收藏/设置图标、未读 badge;
  - 中栏 260~320px:会话列表 / 联系人列表(随侧栏切换);
  - 右栏:会话详情区,内置**嵌套 Navigator**(独立 `GlobalKey<NavigatorState>`),
    群信息、聊天记录搜索等二级页在右栏内部导航或以侧抽屉/Dialog 呈现。
- 叶子组件复用而非重写:会话列表 cell、消息 cell、输入栏、联系人列表都是现成的,
  需要的重构是**把组件内硬编码的 Navigator.push 提升为回调注入**
  (如 `ConversationListWidget(onConversationSelected:)`),只改桌面 Shell 用到的
  组件(估计 6~8 个文件),不动其余 30 个。
- "当前选中会话"进 `ConversationViewModel`(或新建 `PCShellViewModel`),
  右栏由它驱动;手机端不用这个状态,互不影响。

### 方案 C:桌面端完全独立的 UI 工程

彻底重写,与手机零共享。消息 cell、输入栏、20+ 种消息类型的 cell_builder 全部重做,
成本 3~5 倍于方案 B,demo 项目不值得。

**建议:方案 B。** 关键权衡点(可与 GPT 深入讨论):
1. 平台分流 vs 宽度分流——建议先按平台写死,窗口宽度只影响栏宽,不做形态切换,留扩展口;
2. 复用组件的"回调注入"改造是一次性的架构税,但它同时让手机端导航也变得可测试;
3. 双形态维护成本:此后共享组件(消息 cell、输入栏)任何改动都要双端回归——demo 项目可接受,商业项目需要 CI 双端构建保障。

## 2. 分项适配方案

### 2.1 登录(P0)

桌面端 IM 的标配是**二维码登录**,且服务端/手机端链路已有一半:

```
桌面端:POST /pc_session(携带桌面端 clientId + platform)→ 得 token → qr_flutter 展示二维码
手机端:扫码 → PCLoginScreen(已实现)→ confirm_pc
桌面端:轮询 POST /session_login/{token} → 得 userId + IM token → Imclient.connect
```

- 手机侧三件套(`scan_pc`/`confirm_pc`/`cancel_pc`)已在 `app_server.dart`,
  **待确认**:所用 app server 版本是否含 `create_pc_session` / `session_login`
  接口(野火官方 AppService 有,自建的需核对)。
- 注意 token 与 clientId 绑定:二维码里带的必须是**桌面端**的 clientId,
  `Imclient.clientId` FFI 路径已验证可用。
- 备选/降级:手机号验证码登录直接复用 `login_screen.dart`(桌面也能跑),
  可作为 M1 期间二维码链路未通时的过渡。
- 需确认桌面端 connect 时 SDK 上报的 platform 类型(影响服务端多端在线互踢策略、
  以及手机端"PC 已登录"横幅、`isMuteNotificationWhenPcOnline`)。

### 2.2 会话页(P0,工作量最大)

- `ConversationScreen`(556 行)拆为"可嵌入的 `ConversationPane`(消息列表+输入栏)"
  与"手机壳(Scaffold+AppBar)",桌面右栏直接用 Pane;
- 输入栏桌面形态:
  - 多行 `TextField` + `Shortcuts`/`Actions`:**Enter 发送、Shift+Enter 换行**(可设置反转);
  - 去掉语音按钮、拍摄入口;工具条横排:表情、文件、截图(P2)、历史记录;
  - **粘贴图片/文件**(`super_clipboard` 或 Flutter 内建 clipboard API 读图);
  - **拖拽文件进会话**发文件消息(`desktop_drop`);
- 消息操作:长按菜单同逻辑接到**右键**(`onSecondaryTapUp` + `showMenu` 定位到鼠标),
  菜单项复用现有(复制/引用/转发/撤回/删除/多选);
- 鼠标体验:消息区 `Scrollbar`、cell hover 高亮、链接 hover 手型;
- 已读回执、@ 补全等现有逻辑不动。

### 2.3 窗口与系统集成(P1)

| 能力 | 插件 | 说明 |
|------|------|------|
| 窗口尺寸/位置记忆、最小尺寸 | `window_manager` | 最小 ~900×640 |
| 关闭进托盘、托盘菜单、未读闪烁 | `tray_manager` | Linux 各桌面环境行为差异大,降级为纯图标 |
| 桌面通知 | macOS/Linux: `flutter_local_notifications`(已依赖,17.x 支持这两端);Windows: 需补 `windows_notification` 或 `local_notifier` | 点击通知 → 激活窗口 + 跳会话;替换 `wfc_notification_manager.dart` 的 Android-only 判断为平台策略类 |
| 单实例 | `windows_single_instance` / macOS 天然 | 二次启动只激活已有窗口 |
| Dock/任务栏 badge | macOS 原生 API;Windows overlay icon | P2 |
| 开机自启 | `launch_at_startup` | P2 |

**依赖红线(本仓库特有)**:pubspec 是移动/鸿蒙/桌面共享的,任何新增桌面插件
必须确认在 ohos fork SDK 下 `pub get` + ohos 构建不炸(纯桌面插件通常安全,
`window_manager`/`tray_manager` 无 ohos 平台实现、构建时不参与,但需实测一次)。

### 2.4 平台能力替换矩阵(P1)

| 手机端能力 | 桌面替代 | 备注 |
|------------|----------|------|
| 拍照/相册选图 | `file_picker`(已依赖,桌面支持) | `plugin_board.dart` 桌面分支从"toast 不支持"改为文件选择 |
| 扫一扫 | **删除入口**,桌面展示"我的二维码"给手机扫 | mobile_scanner 不需要桌面实现 |
| 语音消息录制 | P2 或不做(参照微信 PC 也弱化);**播放**需验证 `flutter_sound` 桌面表现 + `getWavData` 桌面 stub 问题(DESKTOP_STATUS 6.4) | |
| 视频消息播放 | **坑**:`video_player` 官方无 Windows/Linux 实现 → 引入 `media_kit`,或降级"点击用系统播放器打开" | media_kit 无 ohos 适配,引入前必须验证 ohos 构建;降级方案零风险,建议 M1 先降级 |
| workspace(webview) | `webview_flutter` 桌面不支持 → 桌面隐藏该 tab 或 `url_launcher` 外开浏览器 | |
| 音视频通话 | 维持门控(rtckit 无桌面实现);入口置灰 + 提示 | 若未来要做,是独立大项目 |
| Toast | 抽 `showToast()` 工具类:移动走 fluttertoast,桌面用 Overlay 自绘 | macOS 现靠 podspec 里 20 行 shim,不可持续且 Win/Linux 没有 |
| permission_handler | 桌面 no-op 门控 | |

### 2.5 手机端联动(P2)

- 手机端"PC 已登录"状态横幅(会话列表顶部)+ "手机端静音"开关
  (`isMuteNotificationWhenPcOnline` SDK 已有,桌面 stub 状态需复核);
- 手机端"退出 PC 登录"(kick PC client,SDK `kickoffPCClient` 能力核对)。

## 3. 里程碑

| 阶段 | 内容 | 估时 |
|------|------|------|
| M0 | 架构落地:入口分流、三栏 Shell、嵌套 Navigator、选中会话状态;导航回调注入重构(会话列表/联系人列表) | 2~3 天 |
| M1 | 核心闭环:二维码登录、会话列表、文本/图片/文件收发、右键菜单、Enter 发送、`ConversationScreen` 拆分 | 1~1.5 周 |
| M2 | 系统集成:窗口管理、托盘、三平台通知、粘贴/拖拽、Toast 抽象 | 3~5 天 |
| M3 | 补全:联系人/群管理页右栏化、全局搜索、设置页、媒体预览大图、视频消息方案定稿 | 1 周 |
| M4 | 打包分发:dmg / msix / AppImage+deb,图标与签名 | 按需 |

每阶段收尾必须做一轮**手机端回归**(共享组件被动了的部分),这是方案 B 的固定税。

## 4. 主要风险与开放问题(建议和 GPT 重点讨论)

1. **导航解耦的边界**:回调注入只做 Shell 直接复用的组件,还是顺势引入全局
   `NavigationService`/路由表把 105 处 push 全收编?前者快、后者彻底。
   我倾向前者(demo 项目,增量演进)。
2. **嵌套 Navigator vs 无导航纯状态切换**:右栏用嵌套 Navigator(二级页可以 push,
   复用现有页面代码)还是纯 `IndexedStack` 状态机(更"桌面",但每个二级页都要改造)?
   建议嵌套 Navigator 起步。
3. **video_player 桌面缺口**:media_kit(体积 +~30MB、ohos 兼容未知)vs
   系统播放器外开(零成本、体验降级)。建议先外开,media_kit 做独立 spike。
4. **app server 接口核对**:`create_pc_session`/`session_login` 是否可用,
   决定二维码登录能否进 M1。
5. **多窗口**(独立聊天窗、图片查看器窗):Flutter 桌面多窗口仍不成熟
   (`desktop_multi_window` 有 engine 级限制),**建议明确不做**,全部单窗口内解决。
6. **窗口关闭语义**:直接退出 vs 收进托盘(IM 惯例是托盘),Linux 上托盘不可靠,
   需要平台差异化默认值。
