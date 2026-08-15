# Pad 适配计划

野火 IM Flutter 端目前已适配**移动端**(Android/iOS/鸿蒙手机)和 **PC 端**(Windows/macOS/Linux/鸿蒙电脑)两种形态。本文记录 **pad(iPad / Android 平板 / 鸿蒙平板)** 这第三种形态的适配调研结论与分阶段计划。

> **总原则:移动端与 PC 端的现状(交互、视觉、功能)在整个适配过程中必须零变化。**
> 任何一步改动如果无法证明对手机和 PC 无影响,就不做。

---

## 一、调研结论

### 1.1 Pad 现在的实际状态

| 平台 | 能否安装运行 | 走哪套 UI | 上报平台号 |
|---|---|---|---|
| iPad | ✅ `TARGETED_DEVICE_FAMILY = "1,2"`,四个方向都已开 | ❌ `HomeTabBar` 手机单栏拉满全屏 | ❌ iOS=1(应为 iPad=8) |
| Android 平板 | ✅ manifest 无 `screenOrientation` 锁,`configChanges` 已含 `screenSize\|screenLayout` | ❌ 同上 | ❌ Android=2(应为 APad=9) |
| 鸿蒙平板 | ✅ `WfcPlatform` 已能识别 `tablet` | ❌ 同上 | ✅ HarmonyPad=11 已正确 |

即:三种 pad 都能跑,但都被 `WfcPlatform.isMobile` 归到手机档,完全没有适配。

### 1.2 已有的架构红利(不用推倒重来)

- **形态判断已收敛到唯一源头** `imclient/lib/imclient_platform.dart` 的 `WfcPlatform`,并且已经有 `isDesktop`(UI 形态)/ `isNativeDesktop`(原生能力)**正交拆分的先例** —— 鸿蒙电脑跑三栏 Shell 但没有 window_manager/托盘。这正是 pad 需要的模式:要多栏布局,不要桌面原生能力。
- **`ConversationPane` 已把输入栏做成注入参数**(移动 `MessageInputBar` / 桌面 `PcMessageInputBar`),pad 两栏可直接复用消息区 + 移动输入栏。
- **导航已有唯一入口** `chat/lib/app_navigator.dart`:`openConversation` / `openPage` 按"能否取到 `PCShellViewModel`"分流。**pad 只要注册一个 ShellViewModel,全部共享页面自动在右栏打开,88 个调用点一行都不用改。**这是最大的一笔存量红利。
- `PcPaneContent`(正文最大宽度契约)、`LayoutScale`(字号→布局尺寸)可直接复用。

### 1.3 核心障碍:`isDesktopShell` 一个开关背了四件事

250 处、88 个文件。抽样后它实际同时表达:

| 语义 | 典型证据 | 手机 | PC | **pad 应该是** |
|---|---|---|---|---|
| a. 布局形态 单栏/多栏 | `main.dart` 选 home、`app_navigator`、`PcPaneContent`、`conversation_pane.dart:451` 滚动物理 | 单栏 | 多栏 | **宽时多栏** |
| b. 视觉密度 | 行高 64 vs 72、padding 11 vs 15、AppBar vs PcPageHeader、`app_theme.dart:160-192` 按钮尺寸 | 松 | 密 | **松**(触控热区不能 <44) |
| c. 交互模型 | `HoverBuilder`、选中态高亮、右键菜单 `conversation_list_widget.dart:846`、Enter 发送 | 触摸 | 指针 | **触摸** |
| d. 原生能力 | 已拆成 `isNativeDesktop`(32 处)✅ | 无 | 有 | 无 |

**结论:pad 既不能复用 `isDesktopShell = true`(会连带拿到 b+c,得到一个手指点不准的 PC 界面),也不能保持 `false`(拿不到 a)。必须先拆轴。**这是本次适配的主要工作量,也是最大回归风险。

### 1.4 第二个障碍:窗口尺寸是运行时可变的

`chat/lib/pc/pc_platform.dart` 的注释里明确写死了"按平台分流而非按窗口宽度"。但 pad 上窗口宽度**运行时会变**:旋转、iPad 分屏/台前调度、Android 分屏、折叠屏展开——同一进程内宽度在 320↔1200 之间来回跳。

pad 这一档**必须**引入宽度断点,且断点跨越时布局要能双向切换而不丢状态。这是对现有设计前提的一次扩展,不是照搬。

### 1.5 已定位到行的具体缺陷

**气泡宽度按屏幕宽算而非面板宽算**(两栏形态下一律偏宽):

- `chat/lib/conversation/cell_builder/articles_cell_builder.dart:51` — `size.width * 0.75`
- `chat/lib/conversation/cell_builder/link_cell_builder.dart:23-25`
- `chat/lib/conversation/cell_builder/card_cell_builder.dart:22`
- `chat/lib/conversation/cell_builder/rich_notification_cell_builder.dart:82`
- `chat/lib/conversation/cell_builder/file_cell_builder.dart:48` — **最严重**,直接读 `PlatformDispatcher.instance.views.first.physicalSize.width / 3`,完全绕过布局约束
- `chat/lib/conversation/cell_builder/portrait_cell_builder.dart:143` — 用的是 `constraints.maxWidth`(正确),但 `desktopBubbleInset = 120` 只在 `isDesktopShell` 生效 → pad 两栏下气泡会横贯整个面板

**其他:**

- `chat/lib/conversation/input_bar/record_widget.dart:218` — 录音遮罩按屏幕宽高铺满,两栏下会盖住整个屏幕而非会话面板
- `chat/lib/conversation/input_bar/message_input_bar.dart:20` — 键盘高度只存了一个 key `saved_keyboard_height`,没有方向维度;pad 旋转后表情/插件面板会先按错误高度弹出再纠正
- 平台号映射表 `imclient_platform.dart:102` 的注释里已写了 iPad=8 / APad=9,代码里没实现
- 登录页:pad 上 `isDesktopShell=false` → `LoginScreen` 手机版拉伸;`PCQRLoginScreen` 是固定小窗扫码,pad 也不该用

### 1.6 明确不做的事

1. **不让 pad 复用 `PCHome`** —— 除触控热区问题外,`pc_home.dart:338` 的 `windowManager.hide()` 和 `:978` 的 `windowManager.startDragging()` 都没有 `isNativeDesktop` 门控。
2. **不把 `isDesktopShell` 改成 `isDesktopShell || isTablet`** —— 这正是阶段 1 要拆掉的耦合。
3. **不在 pad 上引入** `desktop_multi_window` / `tray_manager` / 截图。

---

## 二、分阶段计划

### 阶段 0 — 形态识别(imclient 基础设施)✅ 已完成

给 `WfcPlatform` 补上跨平台的设备形态判定,并修正协议平台号。**本阶段不触碰任何 UI**。

1. `OhosDeviceType` 泛化为跨平台 `WfcDeviceType { unknown, phone, tablet, pc }`,`WfcPlatform` 新增 `deviceType` / `isTablet`。
2. **iOS**:`ImclientPlugin.m` 加 `getDeviceType`,按 `UIUserInterfaceIdiomPad` 返回 `tablet`/`phone`。
3. **Android**:`ImclientPlugin.java` 加 `getDeviceType`,按**设备全局**最小宽度 ≥ 600dp 判定。
   ⚠️ 不能用 Activity/应用 Context 的 `Configuration.smallestScreenWidthDp` —— 分屏/自由窗口下它反映的是当前窗口,窗口一缩就变成 phone,而平台号是连接期一次性上报的,不允许随窗口抖动。用 `Resources.getSystem().getConfiguration()`(默认显示屏的全局配置)。
4. **鸿蒙**:已实现,不动。
5. `clientPlatformCodeFor` 补 iPad=8 / APad=9。
6. **`isMobile` / `isDesktop` / `isNativeDesktop` / `useFfiChannel` 语义完全不变** —— pad 在"原生能力"这一轴上仍属移动档。

**兼容性保证(为什么手机端零风险):**

- 查询失败 / native 未重编 → `MissingPluginException` 被 `init()` 的 try-catch 吞掉 → `WfcDeviceType.unknown` → 平台号回落 iOS=1 / Android=2,与今天**逐位相同**。
- 手机上查询成功返回 `phone` → 平台号同样是 1/2,不变。
- 只有 pad 上的返回值会变(1→8 / 2→9),这正是本阶段的目的。

⚠️ **需要注意的服务端语义变化**:平台号参与服务端的多端在线互踢/静音判定与离线推送目标选择(见 `PUSH_PLAN.md`)。iPad 从 1 变 8 后,iPhone 与 iPad 在服务端不再是同一类端,互踢行为会变。**上线前需与 im-server 侧确认 8/9 已被支持**,否则可能出现登录被拒或推送不达。

⚠️ 本阶段改了 iOS/Android 原生代码,**热重载无效,必须重新 `flutter run`**。

### 阶段 1 — 拆轴(chat,纯重构,零行为变化)✅ 已完成

`isDesktopShell` 已删除(`chat/lib/pc/pc_platform.dart` 一并移除),250 处判断点按语义分流到
`chat/lib/app_shell.dart` 的三条轴,外加一个"不属于 UI"的兜底桶:

```dart
AppShell.isMultiPane(context)  // 布局形态,阶段 2 起依赖运行时窗口宽    3 处
AppShell.isDesktopStyle        // 桌面视觉与产品形态(密度/配色/头部栏)  194 处
AppShell.isPointerInput        // hover / 右键 / 快捷键 / 无触摸手势     28 处
WfcPlatform.isDesktop          // 平台实现差异,与 UI 无关                24 处
WfcPlatform.isNativeDesktop    // 原生能力(已有,本阶段未动)
```

映射:

| | [isMultiPane] | [isDesktopStyle] | [isPointerInput] |
|---|---|---|---|
| 手机 | 单栏 | 松 | 触摸 |
| PC | 多栏 | 密 | 指针 |
| pad | 宽时多栏 | **松** | **触摸** |

**为什么需要第四个桶**:有一批判断既不是布局也不是视觉更不是交互,而是**平台实现差异**
——备份包的 `appType`、桌面 WebView 的 UA 标记、通话走不走子窗口代理、大文件上传通道、
"本机是不是 PC"(会话列表的"PC 已登录"横幅)。这些跟着 `WfcPlatform.isDesktop` 走即可,
硬塞进三条轴只会让轴的语义失真。**pad 与移动端 SDK 一致**,所以这一桶在 pad 上一律取
移动端路径,正是想要的结果。

**零行为变化的依据**:三条轴与兜底桶当前**全部**求值为 `WfcPlatform.isDesktop`,与
`isDesktopShell` 逐位相同 —— 这是构造性保证,不依赖逐点复核。分轴的收益要到阶段 2
`isMultiPane` 接上宽度断点时才兑现。

**阶段 2 需要回头复核的 `isDesktopStyle` 站点**(当前判为"视觉",但实际与栏耦合):

- `conversation_list_widget.dart` 列表 `backgroundColor: transparent` —— 桌面靠 PCHome 铺
  中栏底色;pad 两栏时若列表透明而无人铺底会露出空白。
- 同文件的 cell 选中态高亮(`isSelected` → 白字/选中底色)—— 选中态只在多栏形态下有意义。

这两处刻意**没有**用 `isMultiPane`:提前跟着窗口宽翻会在 Shell 落地前就露馅。

**验证**:`flutter analyze` 0 error,问题总数与迁移前基线一致(363 → 363,说明没有新增
告警或残留未使用 import);`flutter test` 86 通过,唯一失败是未纳入 git 的 Flutter 模板残留
`widget_test.dart`(它找的 `'Running on:'` 在 `lib/` 中出现 0 次,且裸 pump `MyApp()` 缺
`Consumer3` 所需的三个 Provider),与本次改动无关。

### 阶段 2 — pad 两栏 Shell

- 新增 `AdaptiveHome`:窗口宽 ≥ 断点走两栏(列表 + 详情),否则回落 `HomeTabBar`。
- **断点 720dp**(已定义为 `AppShell.multiPaneBreakpoint`):iPad mini 竖屏 744pt 刚好进两栏;
  iPad 1/3 分屏(320–375)自动回落单栏。
- 打开 `AppShell.isMultiPane` 的平板分支即可,调用点无需再改 —— 签名里的 `context` 就是
  为此保留的。**已确认 `MediaQuery` 可用**:`runApp` 经 `wrapWithDefaultView` 套的 `View`
  会插入一层 `MediaQuery`,所以 `main.dart` 里位于 `MaterialApp` **之上**的 `_buildHome()`
  也能安全取窗口宽,不必为了拿 MediaQuery 而把 home 包一层 `Builder`。
- Shell 的**装配**(`ShellViewModel` 注册、`PcLayoutViewModel`)在 `main()` 里,那里没有
  BuildContext,阶段 1 归到了 `WfcPlatform.isDesktop`。阶段 2 改成平板也无条件注册即可
  (代价极小),真正决定用不用多栏的仍是 `isMultiPane`。
- **不照搬 PCHome 三栏**:pad 不需要 60px 图标侧栏,tab 用底部 `NavigationBar`(<900)或左侧 `NavigationRail`(≥900)。
- 右栏复用 `ConversationPane` + **移动版** `MessageInputBar`(已支持注入),不用 `PcConversationPane`。
- 注册 ShellViewModel(建议 `PCShellViewModel` 更名为 `ShellViewModel`)→ `app_navigator` 自动生效。
- **状态保持**:选中会话 id 存在 ShellViewModel 里,单栏↔两栏切换时翻译成 push/pop,不能依赖 widget 树里的局部 state。

### 阶段 3 — 面板宽度正确性(缺陷修复)

- 1.5 节列出的 5 个 cell_builder 从 `MediaQuery` / `PlatformDispatcher` 改为 `LayoutBuilder` 的 `constraints`。
- `desktopBubbleInset` 改成"气泡最大宽度"语义,按面板宽计算,多栏形态统一生效。
- `record_widget` 全屏遮罩改挂到会话面板的 Overlay。
- 逐条走查 23 处 `MediaQuery.size`。

### 阶段 4 — pad 专属体验

- 登录页:pad 用居中卡片(既非手机全宽、也非 PC 扫码小窗)。
- 旋转:键盘高度缓存按方向分别存;会话列表滚动位置保持。
- 外接键盘/触控板(iPadOS):`AmbientShortcuts` 已是统一入口可直接接;方向键必须走 `beforeFocus` 档。
- 相册/相机:`wechat_assets_picker` / `wechat_camera_picker` 在 iPad 上是手机版栅格,需评估列数;第三方包,可能只能接受现状。
- 通话:`conference` 已有 mobile/grid/speaker 三套 layout,大概率可用;`voip_call_screen` 横屏需单独验。
- 分屏/台前调度:确认窗口宽变化不会触发 IM 重连。

### 阶段 5 — 验证

- 设备矩阵:iPad(竖/横、1:1 与 1:3 分屏、台前调度)、Android 平板(竖/横/分屏)、鸿蒙平板、折叠屏展开↔折叠。
- **回归重点是手机端与 PC 端零变化**。
- 可单测的:`clientPlatformCodeFor` 映射表、`parseDeviceType`、断点选择函数、`AppShell` 各轴取值。
