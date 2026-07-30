# PC 端独立子窗口（通话/媒体预览/朋友圈/搜索）IPC 方案设计文档

## 1. 背景与目标

### 1.1 为什么需要独立窗口？

在移动端，音视频通话界面通常以全屏路由的形式覆盖在主界面上。PC 端（macOS/Windows/Linux）则不同：

- 用户希望在通话的同时继续操作聊天主窗口；
- 通话窗口需要独立的标题栏、尺寸、置顶状态；
- 音视频引擎（WebRTC）持有独立的渲染上下文，放在独立 Engine 里更安全。

因此，PC 端采用「**主窗口负责 IM，通话子窗口负责音视频引擎 + UI**」的架构。

这套架构后来复用到了另外三类子窗口：**媒体预览**（图片/视频独立查看）、**朋友圈**、**会话内搜索**（"聊天记录"窗口）。四类窗口共享同一套 IPC 基础设施和公共层（见 §3、§4），本文以通话窗口为主线，其它三类只在与通话不同的位置单独说明。

### 1.2 为什么需要 IPC？

Flutter 桌面多窗口（通过 `desktop_multi_window`）会为每个子窗口创建**独立的 Dart Isolate / Flutter Engine**：

- 子窗口不能直接访问主窗口的 `Imclient` 单例；
- 子窗口不能直接读取主窗口的内存状态（会话、用户信息、消息等）；
- 主窗口收到的 IM 消息需要通知子窗口；
- 子窗口产生的 IM 发送请求需要主窗口代为执行。

所以主窗口和通话子窗口之间必须通过 **IPC（Inter-Process Communication，这里实质是跨 Engine 的 MethodChannel）** 交换事件和数据。

---

## 2. 总体架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              操作系统桌面                                    │
│                                                                             │
│  ┌───────────────────────────────┐      ┌─────────────────────────────────┐ │
│  │        主窗口 (Main)           │      │      通话子窗口 (Call)           │ │
│  │  ┌─────────────────────────┐  │      │  ┌─────────────────────────────┐│ │
│  │  │  Flutter UI / 聊天列表   │  │      │  │  VoipCallScreen / MultiCall  ││ │
│  │  │  Imclient (真实 IM SDK)  │  │      │  │  ConferenceCallScreen        ││ │
│  │  │  MainAvEngineKitProxy    │  │◄────►│  │  AVEngineKitImpl (真实引擎)   ││ │
│  │  │  - 监听 IM 事件          │  │ IPC  │  │  CallWindowImclientChannel   ││ │
│  │  │  - 创建/管理通话窗口      │  │      │  │  - 把 IM 调用转发给主窗口     ││ │
│  │  │  - 代发 IM 消息/会议请求  │  │      │  │                              ││ │
│  │  └─────────────────────────┘  │      │  └─────────────────────────────┘│ │
│  └───────────────────────────────┘      └─────────────────────────────────┘ │
│                                                                             │
│        ▲                                                                    │
│        │                                                                    │
│        ▼                                                                    │
│  ┌───────────────────────────────┐                                        │
│  │   IM SDK / Mars / libMarsWrapper│（真实网络连接，只在主窗口存在）          │
│  └───────────────────────────────┘                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

媒体预览/朋友圈/搜索窗口与上图同构：主窗口侧各有 `MainXxxProxy`（代执行 IM 调用、转发事件），子窗口侧各有 `XxxWindowImclientChannel`（转发 IM 调用）或干脆不连 IM（媒体预览）。四类窗口的 App 模板、Manager 样板、IM 代理通道都已收敛到 `multi_window/` 公共层，见 §4。

### 2.1 职责划分

| 能力 | 主窗口 | 通话子窗口 |
|------|--------|-----------|
| 真实 IM 连接 | ✅ `Imclient` | ❌ 通过代理转发 |
| 音视频引擎 `AVEngineKit` | ❌ 只有占位代理 | ✅ `AVEngineKitImpl` |
| 通话 UI | ❌ | ✅ |
| WebRTC 视频渲染 | ❌ | ✅ |
| 监听 IM 消息/会议事件 | ✅ | 接收主窗口转发 |
| 发送 VOIP 信令消息 | 代理执行 | 发起请求 |
| 发送会议请求 | 代理执行 | 发起请求 |
| 获取用户信息/群成员 | 代理执行 | 发起请求 |

---

## 3. IPC 通道基础设施

### 3.1 `desktop_multi_window`

项目使用 `desktop_multi_window: ^0.2.0` 创建独立子窗口。该插件提供两类跨窗口通信能力：

1. **`DesktopMultiWindow.createWindow(args)`**：创建子窗口，子窗口进程会重新执行 `main(List<String> args)`，且 `args[0] == 'multi_window'`。
2. **`DesktopMultiWindow.invokeMethod(targetWindowId, method, args)`**：向指定窗口的 Dart isolate 发送方法调用。
3. **`DesktopMultiWindow.setMethodHandler(handler)`**：在当前窗口注册方法调用处理器。

### 3.2 封装：`WindowEventChannel`

文件：`chat/lib/pc/multi_window/window_event_channel.dart`

为了避免主窗口和子窗口直接依赖 `desktop_multi_window` 的 API 细节，项目封装了一个事件通道（每个 isolate 的单例，四类窗口共用）：

```dart
class WindowEventChannel {
  /// 向目标窗口发送事件(主窗口 → 子窗口传 windowId,子窗口 → 主窗口传 0)。
  static Future<T?> invoke<T>(int targetWindowId, String method, dynamic args);

  /// 按事件名注册处理器,然后 listen() 开始接收。
  void register(String method, Future<dynamic> Function(dynamic args) handler);
  void listen();
}
```

实现原理：

- 发送方直接以事件名作为 method,经 `DesktopMultiWindow.invokeMethod` 发到目标窗口;
- 接收方通过 `DesktopMultiWindow.setMethodHandler` 接收,按 method 查找 `register` 过的处理器;
- 跨窗口只传 Map/List/基本类型(method channel 原生支持),`_encode`/`_decode` 仅做
  `Map<Object?,Object?>` → `Map<String,dynamic>` 的类型归一化,**不做 JSON 字符串化**;
- `listen()` 底层的 `setMethodHandler` 是进程内全局唯一,因此本类是每个 isolate 的单例:
  所有功能(通话代理、媒体预览……)把各自的 handler 注册到同一张表上;
- method 命名约定 **`<domain>[.imclient].<method>`**：domain 为窗口/功能域
  （voip / mediaPreview / moment / search 等）；转发 Imclient 调用的代理事件在 domain
  后再加 `.imclient` 一段，如 `moment.imclient.getUserInfo`；
- 同一 method **重复注册**会覆盖旧 handler，覆盖前打 `debugPrint` 告警（多半意味着
  前缀冲突或重复 install），不抛异常。

---

## 4. 多窗口公共层

四类子窗口（call / mediaPreview / moment / search）的样板代码已全部收敛到
`chat/lib/pc/multi_window/`。本章介绍公共层各组件。

### 4.1 窗口种类标识：`window_kind.dart`

子窗口创建参数里用 `kWindowKindKey`（`'_windowKind'`）标识窗口种类，四个取值：

```dart
const String kWindowKindKey = '_windowKind';
const String kCallWindowKind = 'call';
const String kMediaPreviewWindowKind = 'media_preview';
const String kMomentWindowKind = 'moment';
const String kSearchWindowKind = 'search';
```

`main.dart` 的子窗口入口按 kind 显式分发到 `CallWindowApp` / `MediaPreviewWindowApp` /
`MomentWindowApp` / `SearchWindowApp`。历史兼容：`call_window_manager` 早先创建窗口时
不携带 kind，未携带（kind == null）一律落 `CallWindowApp`；无法识别的 kind 打
`debugPrint` 日志后同样落到 Call 窗口。

> 注意区分两组字符串：创建参数 kind 是下划线形式（`'media_preview'`），而媒体预览的
> **事件前缀**是 `'mediaPreview'`（现网事件名如此）。`SubWindowManagerBase` 用
> `windowKind`（事件前缀）和 `creationWindowKind`（创建参数值）两个 getter 表达这个差异。

### 4.2 子窗口专用 Binding：`SubWindowWidgetsBinding`

文件：`chat/lib/pc/multi_window/sub_window_binding.dart`

macOS 多引擎子窗口会收到错误的 hidden/paused 生命周期状态（flutter/flutter#133533），
framework 随即关闭帧调度：setState/Timer 只更新状态不产帧（通话计时不走、来电窗口
停在首帧黑屏），postFrameCallback 也不执行。`SubWindowWidgetsBinding` 把
hidden/paused/detached 一律降级为 inactive，保证帧调度常开。`main.dart` 的子窗口
入口必须使用它而不是默认 binding。

### 4.3 子窗口 App 模板：`SubWindowAppBase`

文件：`chat/lib/pc/multi_window/sub_window_app_base.dart`

`mixin SubWindowAppBase<T extends StatefulWidget> on State<T> implements WindowListener`，
统一四个窗口 App 的 init 流程（偏好 VM → 设 userId → 换 IM 代理通道 → 注册消息类型 →
注册事件 → 发 ready 通知 → setState → postFrame + 1s 兜底初始化 window_manager）、
标题更新（l10n + `_windowManagerInited` 门闩，防偏好加载与 window_manager 初始化并发
导致 macOS 原生崩溃）、关窗通知、主题/字号装载。子类只留钩子：

| 钩子 | 默认 | 说明 |
|------|------|------|
| `windowKind` | 抽象 | 窗口标识，兼作 `<kind>.ready` / `<kind>.windowClosed` 事件前缀 |
| `windowTitle(l10n)` | 抽象 | 窗口标题；l10n 由基类按当前语言解析 |
| `minWindowSize` | 抽象 | 窗口最小尺寸 |
| `buildHome(context)` | 抽象 | ready 后的主内容；未 ready 统一显示加载页 |
| `windowId` / `windowArguments` | 抽象 | 子窗口 Widget 持有的窗口 id 与创建参数（`_selfUserId`、`_windowType` 等从这里取） |
| `imclientChannel` | `null` | 子窗口的 IM 代理通道（媒体预览不连 IM 为 null） |
| `registerMessageContents()` | 空 | 注册消息内容类型（仅 Dart 层解码用） |
| `eventHandlers` | `{}` | 主窗口转发事件的 handler 表 |
| `onWindowReady()` | 空 | 子类初始化（解析 arguments 等），ready 通知前 await |
| `useNormalTitleBar` | `false` | 是否恢复标准标题栏（搜索窗为 true） |
| `notifyReady()` | 发 `<kind>.ready` | 通话覆写为 `voip.statusChanged {status:'ready'}` |
| `applyWindowStyle()` | 标题栏/标题/最小尺寸/show/focus | 通话覆写为会议窗隐藏标题栏 + 透明背景的分支 |
| `extraProviders` | `[]` | 额外 providers（通话的 PCShell/User VM） |
| `navigatorKey` | `null` | MaterialApp navigatorKey（媒体预览的 toast Overlay） |
| `buildLightTheme/buildDarkTheme/themeMode` | AppTheme + 跟随设置 | 通话/媒体预览覆写为强制暗色 |
| `buildLoading(context)` | 居中 spinner | 未 ready 加载页 |

**全局水印**：基类的 `MaterialApp.builder` 在内容之上叠了一层
`WatermarkOverlay`（`chat/lib/widget/watermark_overlay.dart`），四类子窗口与主窗口
一样覆盖全局安全水印（用户 ID + 分钟精度时间，`Config.ENABLE_WATER_MARKER` 开关）。
userId 优先取构造函数传入值（主窗口用法）；子窗口未传，回退
`Imclient.currentUserId`——基类 `_init` 第一步已用创建参数 `_selfUserId` 把它设好
（四类子窗口创建时都注入，见 §4.4）。

> 标题栏相关的另一处差异在**主窗口**：Windows 主窗口在
> `PCWindowManager.ensureInitialized()` 中 `setTitleBarStyle(hidden)`，改由
> `chat/lib/pc/widgets/pc_window_caption.dart` 自绘标题栏（整条可拖动、双击切换
> 最大化，右侧最小化/最大化/关闭按钮）。子窗口不经过 `PCWindowManager`，不受影响。

### 4.4 主窗口侧 Manager 模板：`SubWindowManagerBase`

文件：`chat/lib/pc/multi_window/sub_window_manager_base.dart`

统一四个 Manager 的 `_windowController` / `_windowReady` / `_handlersInstalled` 三字段、
create→setFrame→center→show 创建序列（先 center 再 show，防角落闪帧）、ready
（windowId 校验 + `onSubWindowReady` 钩子）和 windowClosed（按 windowId 防迟到过滤）
处理、handler 懒安装。复用策略由子类声明：

| reusePolicy | 行为 | 使用者 |
|-------------|------|--------|
| `raiseOnly` | 已开窗仅置顶，失效则重建 | 朋友圈 |
| `updateContent` | 置顶前先发内容更新事件 | 搜索（发 `search.updateConversation`）；媒体预览声明同策略，但 pending 补发逻辑特殊，复用由 `show()` 自行实现 |
| `recreate` | 不复用，先关再开 | 通话 |

创建参数由基类统一注入 `kWindowKindKey` 与 `_selfUserId`（`injectSelfUserId`
默认 true，**四类子窗口均注入**：连接 IM 的子窗口业务需要；媒体预览窗虽不连 IM，
也靠它在子窗口侧设置 `Imclient.currentUserId`，供全局水印显示用户 ID，见 §4.3）。

### 4.5 子窗口 IM 代理通道：`ProxyImclientChannel`

文件：`chat/lib/pc/multi_window/proxy_imclient_channel.dart`

`ProxyImclientChannel implements ImclientChannel`，构造参数为事件前缀
（如 `'moment.imclient'`），子窗口 Channel 在构造时用声明式方法表注册转发规则：

- `forwardSimple(method)`：按原 args 转发 `$prefix.$method`，回传主窗口结果；
- `forward(method, {event, reshapeArgs})`：先整形参数（或改事件名）再转发；
- `forwardWithRequestId(method, dispatch, {event, makeRequest})`：回调式接口。
  从 args 取 requestId，主窗口同步返回 `{errorCode, result}`（或 files 等字段）后交给
  dispatch 闭包走 `ImclientPlatform` 的 dispatch 方法触发回调并清理。

`registerMessage` 直接返回 null（消息类型注册只作用于 Dart 层解码，原生侧已在主窗口
完成注册）；未注册的方法抛 `UnsupportedError`；`setMethodCallHandler` 空实现。
三个子窗口 Channel（CallWindowImclientChannel / MomentWindowImclientChannel /
SearchWindowImclientChannel）均基于它，见 §7.1。

### 4.6 主窗口侧回调包装：`ProxyCompleter`

文件：`chat/lib/pc/multi_window/proxy_completer.dart`

主窗口 proxy 把 Imclient 的 callback 式 API 包装成 Future 的统一助手，结果统一编成
`{errorCode, ...}` map 回传子窗口：`stringResult`（字符串结果）、`filesResult`
（文件记录列表）、`voidResult`（无参成功），与子窗口侧三类 dispatch 一一对应。

### 4.7 四类窗口 × 文件 × 事件前缀对照

| 窗口 | 子窗口目录 | 事件前缀 | 主窗口 proxy |
|------|-----------|---------|-------------|
| 通话 | `pc/call_window/` | `voip.*`（下行）、`imclient.*`（上行 IM 代理） | `MainAvEngineKitProxy` |
| 媒体预览 | `pc/media_preview_window/` | `mediaPreview.*` | 无（Manager 直接代查 loadMore） |
| 朋友圈 | `pc/moment_window/` | `moment.*`、`moment.imclient.*` | `MainMomentProxy` |
| 会话搜索 | `pc/search_window/` | `search.*`、`search.imclient.*` | `MainSearchProxy` |

---

## 5. 事件协议

### 5.1 主窗口 → 子窗口（下行事件）

事件名常量定义在 `chat/lib/pc/call_window/call_window_events.dart` 的
`CallWindowEvents`(统一 `voip.` 前缀):

```dart
class CallWindowEvents {
  static const String message = 'voip.message';
  static const String conferenceEvent = 'voip.conferenceEvent';
  static const String connectionStatus = 'voip.connectionStatus';
  static const String sendMessageResult = 'voip.sendMessageResult';
  static const String startCall = 'voip.startCall';
  static const String startConference = 'voip.startConference';
  static const String joinConference = 'voip.joinConference';
}
```

| 事件 | 触发时机 | 参数 | 子窗口处理 |
|------|---------|------|-----------|
| `voip.startCall` | 用户主动发起通话 | 会话、participants、audioOnly、callExtra | `avEngineKit.startCall` |
| `voip.startConference` / `voip.joinConference` | 创建/加入会议 | callId、audioOnly、pin、host 等 | `avEngineKit.startConference/joinConference` |
| `voip.message` | 主窗口收到 VOIP 相关 IM 消息 | 序列化的 `Message` | 解码后 fire `ReceiveMessagesEvent` 到子窗口 IMEventBus(avenginekit、ConferenceManager 等订阅者共享) |
| `voip.conferenceEvent` | 主窗口收到会议事件 | 事件字符串 | fire `ConferenceEvent` 到子窗口 IMEventBus |
| `voip.connectionStatus` | IM 连接状态变化 | 状态码 | fire `ConnectionStatusChangedEvent` 到子窗口 IMEventBus |
| `voip.sendMessageResult` | 主窗口 sendMessage 收到服务器 ack/失败 | requestId、errorCode、messageUid、timestamp | `ImclientPlatform.dispatchSendMessageResult` 触发回调并清理 |

> 子窗口把主窗口转发的事件统一 fire 到本 isolate 的 `IMEventBus`,与移动端的
> 事件分发保持同构——**不要**绕过总线直调 `avEngineKit`,否则其它总线订阅者
> (如 `ConferenceManager`)收不到消息。

### 5.2 子窗口 → 主窗口（上行调用）

通话子窗口需要主窗口代为执行的 IM 操作与状态通知，常量在同一个文件的
`MainWindowEvents`(统一 `imclient.` 前缀,窗口状态类用 `voip.` 前缀):

```dart
class MainWindowEvents {
  static const String sendMessage = 'imclient.sendMessage';
  static const String sendConferenceRequest = 'imclient.sendConferenceRequest';
  static const String updateMessageContent = 'imclient.updateMessageContent';
  static const String getMessageByUid = 'imclient.getMessageByUid';
  static const String getUserInfo = 'imclient.getUserInfo';
  static const String getUserInfos = 'imclient.getUserInfos';
  static const String getGroupMembers = 'imclient.getGroupMembers';
  static const String joinChatroom = 'imclient.joinChatroom';
  static const String quitChatroom = 'imclient.quitChatroom';
  static const String currentUserId = 'imclient.currentUserId';
  static const String clientId = 'imclient.clientId';
  static const String connectionStatus = 'imclient.connectionStatus';
  static const String isLogined = 'imclient.isLogined';
  static const String serverDeltaTime = 'imclient.serverDeltaTime';
  static const String voipStatusChanged = 'voip.statusChanged';
  static const String windowClosed = 'voip.windowClosed';
}
```

| 调用 | 用途 | 返回 |
|------|------|------|
| `sendMessage` | 子窗口让主窗口发送 VOIP 信令消息 | 序列化后的 Message |
| `sendConferenceRequest` | 子窗口让主窗口发送会议请求 | HTTP 结果字符串 |
| `getUserInfo` / `getUserInfos` | 获取远端用户头像/昵称 | 序列化后的 UserInfo 列表 |
| `getGroupMembers` | 多人通话获取群成员信息 | 序列化后的 GroupMember 列表 |
| `getMessageByUid` | 查询已发送信令消息 | 序列化后的 Message |
| `updateMessageContent` | 更新本地通话记录消息（方法名 `updateMessage` → 事件名 `imclient.updateMessageContent`） | 无 |
| `joinChatroom` / `quitChatroom` | 会议聊天室进出 | 无（回调式） |
| `currentUserId` / `clientId` / `connectionStatus` / `isLogined` / `serverDeltaTime` | 子窗口读主窗口 IM 状态 | 对应标量 |
| `voip.statusChanged` | 子窗口 → 主窗口：`{status:'ready'/'ended', ...}`，通话窗的"就绪"通知走它而不是 `<kind>.ready` | — |
| `voip.windowClosed` | 子窗口通知主窗口通话窗已关闭 | — |

### 5.3 四类窗口的事件前缀与事件名来源

| 前缀 | 用途 | 常量定义文件 |
|------|------|-------------|
| `voip.*` | 通话窗下行事件 + 窗口状态（ready/closed） | `pc/call_window/call_window_events.dart` |
| `imclient.*` | 通话窗上行 IM 代理 | 同上（`MainWindowEvents`） |
| `mediaPreview.*` | 预览窗 show/ready/loadMore/windowClosed | `pc/media_preview_window/media_preview_ipc.dart`（`MediaPreviewEvents`） |
| `moment.*` | 朋友圈窗 ready/refresh/windowClosed | `pc/moment_window/moment_ipc.dart`（`MomentWindowEvents`） |
| `moment.imclient.*` | 朋友圈窗上行 IM 代理 | 同上（`MomentMainEvents`） |
| `search.*` | 搜索窗 ready/updateConversation/locateMessage/windowClosed | `pc/search_window/search_window_ipc.dart`（`SearchWindowEvents`） |
| `search.imclient.*` | 搜索窗上行 IM 代理 | 同上（`SearchMainEvents`） |

---

## 6. 数据序列化

主窗口和子窗口运行在不同 isolate，所有跨窗口传递的对象必须序列化为 `Map<String, dynamic>` 或 JSON。

### 6.1 线格式唯一定义处：`IpcCodec`

文件：`chat/lib/pc/multi_window/ipc_codec.dart`

`Message` / `MessagePayload` / `Conversation` 与 Map 的互转只在 `IpcCodec` 一处实现,
主窗口编码、子窗口解码、`RawVoipMessageContent` 全部复用它:

```dart
class IpcCodec {
  static Map<String, dynamic> encodeMessage(Message message);
  static Map<String, dynamic> encodePayload(MessagePayload payload);
  static MessagePayload decodePayload(Map<dynamic, dynamic> map);
  static Map<String, dynamic> encodeConversation(Conversation conversation);
  static Conversation decodeConversation(Map<dynamic, dynamic> map);
}
```

**线格式与 imclient 的 proto map 完全一致**(payload 与 conversation 都用 `'type'` key、
`binaryContent` 为 base64),因此子窗口把主窗口返回的 map 直接交给
`ImclientPlatform` 的 `_convertProtoXxx` 即可解析,SDK 层无需为 IPC 添加任何 key 别名。

编码后的消息结构：

```json
{
  "messageId": 123,
  "messageUid": 456,
  "conversation": {"type": 0, "target": "userId", "line": 0},
  "fromUser": "userId",
  "toUsers": ["userId"],
  "direction": 0,
  "status": 0,
  "serverTime": 1783927749301,
  "localExtra": null,
  "content": {
    "type": 400,
    "searchableContent": "...",
    "binaryContent": "base64...",
    ...
  }
}
```

`binaryContent` 解码兼容 `Uint8List`、`List<int>`(MethodChannel 透传后常被重新
实例化为 `_GrowableList`)和 base64 字符串三种形态。

子窗口侧的 `VoipMessageCodec`(`voip_message_codec.dart`)只负责按 contentType
实例化 avenginekit 的具体消息内容类,线格式解析全部委托 `IpcCodec`。媒体预览窗的
`MediaPreviewCodec`（`media_preview_ipc.dart`）同样构建在 `IpcCodec` 之上，只额外做
图片/视频内容类实例化和缩略图裁剪。

### 6.2 主窗口占位 VOIP 消息：`RawVoipMessageContent`

文件：`chat/lib/pc/call_window/raw_voip_message_content.dart`

主窗口不需要理解 VOIP 业务，只要能把收到的 VOIP 消息原样透传给子窗口。`RawVoipMessageContent` 是一个通用占位内容类：

- 注册正确的 `MessageFlag`（是否持久、是否计数），让 IM SDK 对 incoming VOIP 消息的处理与 avenginekit 一致；
- 把 `MessagePayload` 按字段原样保存；
- `encode()` 时把 payload 返回给主窗口代理，代理再交给 `VoipMessageCodec` 编码传给子窗口。

### 6.3 用户/群成员信息：`ModelCodec`

文件：`chat/lib/pc/call_window/model_codec.dart`

```dart
class ModelCodec {
  static Map<String, dynamic> encodeUserInfo(UserInfo user);
  static UserInfo decodeUserInfo(Map<String, dynamic> map);
  static Map<String, dynamic> encodeGroupMember(GroupMember member);
  static GroupMember decodeGroupMember(Map<String, dynamic> map);
}
```

关键约定：

- 编码 `UserInfo` 时用 `'uid'` 作为主键，与 IM SDK 内部 `_convertProtoUserInfo` 的字段名一致，避免子窗口侧解析失败；
- 解码时兼容 `'uid'` 和 `'userId'`；
- 所有字段都做了类型容错和缺省值处理。

---

## 7. IM 代理机制详解

### 7.1 子窗口侧：`CallWindowImclientChannel`

文件：`chat/lib/pc/call_window/call_window_imclient_channel.dart`

子窗口启动时**不执行** `Imclient.init`,只把 `ImclientPlatform.instance.channel` 替换为代理通道。
三个连接 IM 的子窗口（通话/朋友圈/搜索）的 Channel 都基于公共层
`ProxyImclientChannel`（见 §4.5），在构造中用声明式方法表注册转发规则：

```dart
class CallWindowImclientChannel extends ProxyImclientChannel {
  CallWindowImclientChannel() : super('imclient', ...) {
    forward('sendMessage', reshapeArgs: ...);
    forwardWithRequestId('sendConferenceRequest', _dispatch, makeRequest: ...);
    forward('updateMessage', event: MainWindowEvents.updateMessageContent, ...);
    forwardSimple('currentUserId');
    // ... 共 14 个方法
  }
}
```

朋友圈（前缀 `'moment.imclient'`，9 个方法）与搜索（前缀 `'search.imclient'`，
9 个方法）同构；媒体预览窗不连 IM，没有代理通道（但创建参数仍注入
`_selfUserId`，供全局水印显示用户 ID，见 §4.3/§4.4）。

这样，子窗口里的 `Imclient.sendMessage(...)`、`Imclient.getUserInfo(...)` 等调用，实际上都通过 IPC 发到了主窗口。

`sendMessage` 的回调语义与移动端保持一致(两段式):

1. 代理转发 `sendMessage`,主窗口 `Imclient.sendMessage` 返回**本地入库**的 message,
   原样回传作为子窗口 `sendMessage` 的返回值;
2. 主窗口收到服务器 ack/失败后,经 `voip.sendMessageResult` 事件回传
   `{requestId, errorCode, messageUid, timestamp}`,子窗口调用
   `ImclientPlatform.dispatchSendMessageResult` 按 `onSendMessageSuccess/Failure`
   的既有语义触发回调、更新发送中消息并清理 requestId 关联状态。

字符串结果类回调（`uploadMedia` / `uploadMediaFile` / `getAuthorizedMediaUrl` /
`sendMomentsRequest`，successCallback 均为 `OperationSuccessStringCallback`）走
`ImclientPlatform.dispatchStringResult(requestId, errorCode, {result})`——这是为
子窗口代理新增的语义正确的 dispatch（早前借用名字不符的
`dispatchConferenceRequestResult`）；会议请求仍用 `dispatchConferenceRequestResult`，
文件记录列表/无参成功回调用 `dispatchOperationResult`。

### 7.2 主窗口侧：`MainAvEngineKitProxy`

文件：`chat/lib/pc/call_window/main_avengine_kit_proxy.dart`

主窗口在 `install()` 时：

1. 注册 `RawVoipMessageContent` 占位所有 VOIP 消息类型；
2. 监听 `ReceiveMessagesEvent`、`ConferenceEvent`、`ConnectionStatusChangedEvent`；
3. 在 `WindowEventChannel` 上注册子窗口事件处理器，处理子窗口发回的 IM 代理调用；
4. 处理 `voip.statusChanged`（子窗口 ready/ended）与 `voip.windowClosed`。

收到子窗口的 `sendMessage` 请求后，主窗口执行：

```dart
Future<dynamic> _handleSendMessage(dynamic args) async {
  final conversation = _conversationFromJson(args['conversation']);
  final contentJson = args['content'] as Map<String, dynamic>;
  final content = RawVoipMessageContent.fromMap(contentJson);
  final message = await Imclient.sendMessage(conversation, content.encode(), ...);
  return _messageToJson(message);
}
```

收到子窗口的 `getUserInfo` 请求后：

```dart
Future<dynamic> _handleGetUserInfo(dynamic args) async {
  final userInfo = await Imclient.getUserInfo(args['userId'], refresh: args['refresh']);
  return userInfo != null ? ModelCodec.encodeUserInfo(userInfo) : null;
}
```

朋友圈/搜索窗的主窗口侧对应 `MainMomentProxy` / `MainSearchProxy`，结构相同；
其中 callback 式 API（sendMomentsRequest、uploadMedia、getConversationFiles、
getAuthorizedMediaUrl、deleteFileRecord 等）统一用 `ProxyCompleter`（见 §4.6）把
回调包装成 `{errorCode, ...}` 的 Future 回传。

### 7.3 为什么不能让子窗口直接连接 IM？

项目中的 `Imclient` 底层依赖 `libMarsWrapper` / Mars，通常一个进程只允许一个连接。如果子窗口也尝试初始化真实 IM 连接，会：

- 与主窗口抢占连接，导致主窗口掉线；
- 状态不一致（两个 isolate 各自维护消息状态）；
- 增加复杂度（需要处理双端消息同步）。

所以子窗口只做「代理调用者」，真实 IM 能力集中在主窗口。

---

## 8. 通话生命周期中的 IPC 流程

### 8.1 主动发起通话

```
用户点击视频通话按钮
        │
        ▼
MainAvEngineKitProxy.startCall()
        │
        ▼
CallWindowManager.createCallWindow(type: 'single')
        │
        ▼
desktop_multi_window 创建子窗口，执行 main(['multi_window', windowId, args])
        │
        ▼
CallWindowApp 初始化
  - 替换 ImclientPlatform.channel 为 CallWindowImclientChannel
  - 初始化 AVEngineKitImpl
  - 经 voip.statusChanged {status:'ready'} 通知主窗口 ready
        │
        ▼
主窗口收到 ready，把初始 startCall 事件发给子窗口
        │
        ▼
子窗口 AVEngineKitImpl.startCall() → 创建房间 → 通过代理 sendMessage 发 START 信令
```

### 8.2 收到来电

```
IM SDK 分发 ReceiveMessagesEvent 到主窗口
        │
        ▼
MainAvEngineKitProxy._onReceiveMessages()
  - 识别 VOIP_START / ADD_PARTICIPANT / CONFERENCE_INVITE
  - 若 Call 窗口不存在，先 _ensureCallWindowFromIncomingMessage()
        │
        ▼
子窗口创建并 ready 后，主窗口把 incoming message 事件发过去
        │
        ▼
子窗口 AVEngineKitImpl 处理 incoming message，进入 Incoming 状态
```

### 8.3 通话中交换信令

```
子窗口 AVEngineKitImpl 需要发 Answer / Bye / Signal / Modify 等消息
        │
        ▼
Imclient.sendMessage() → CallWindowImclientChannel.invokeMethod()
        │
        ▼
IPC 到主窗口 MainWindowEvents.sendMessage
        │
        ▼
主窗口 Imclient.sendMessage() 真实发送
        │
        ▼
对方回复的消息经 IM SDK → 主窗口 → _onReceiveMessages → IPC 到子窗口
        │
        ▼
子窗口 AVEngineKitImpl.onReceiveMessages() 处理回复
```

---

## 9. 子窗口原生插件注册

子窗口是独立的 Flutter Engine，桌面端不会自动继承主窗口的插件注册表。因此必须在每个平台的窗口入口里手动注册子窗口可能用到的**原生**插件。

### 9.1 macOS：`MainFlutterWindow.swift`

当前注册 9 个插件（子窗口无托盘用途，`TrayManagerPlugin` 已移除，托盘归主窗口独占）：

```swift
FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
  FlutterWebRTCPlugin.register(with: controller.registrar(forPlugin: "FlutterWebRTCPlugin"))
  WindowManagerPlugin.register(with: controller.registrar(forPlugin: "WindowManagerPlugin"))
  SharedPreferencesPlugin.register(with: controller.registrar(forPlugin: "SharedPreferencesPlugin"))
  PathProviderPlugin.register(with: controller.registrar(forPlugin: "PathProviderPlugin"))
  DeviceInfoPlusMacosPlugin.register(with: controller.registrar(forPlugin: "DeviceInfoPlusMacosPlugin"))
  SqflitePlugin.register(with: controller.registrar(forPlugin: "SqflitePlugin"))
  // 媒体预览窗口:另存为对话框 + 视频降级用系统播放器打开。
  FilePickerPlugin.register(with: controller.registrar(forPlugin: "FilePickerPlugin"))
  UrlLauncherPlugin.register(with: controller.registrar(forPlugin: "UrlLauncherPlugin"))
  // 朋友圈窗口:视频动态播放。
  FVPVideoPlayerPlugin.register(with: controller.registrar(forPlugin: "FVPVideoPlayerPlugin"))
}
```

### 9.2 Windows：`flutter_window.cpp`

当前注册 5 个插件（含 url_launcher，供媒体预览"系统播放器打开"）。子窗口无托盘用途，
**不注册** `TrayManagerPlugin`（托盘归主窗口独占）：tray_manager 的 Windows 实现把
MethodChannel 存在进程级全局变量里，子窗口注册会顶掉主窗口那份——开着子窗口期间托盘
事件全发到子窗口 isolate，子窗口关闭后析构再把它置空，主窗口托盘彻底失效：

```cpp
DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
  auto* registry = reinterpret_cast<flutter::FlutterViewController*>(controller)->engine();
  FlutterWebRTCPluginRegisterWithRegistrar(registry->GetRegistrarForPlugin("FlutterWebRTCPlugin"));
  WindowManagerPluginRegisterWithRegistrar(registry->GetRegistrarForPlugin("WindowManagerPlugin"));
  ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(registry->GetRegistrarForPlugin("ScreenRetrieverWindowsPluginCApi"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
  UrlLauncherWindowsRegisterWithRegistrar(registry->GetRegistrarForPlugin("UrlLauncherWindows"));
  // 统一清单中其余插件(shared_preferences / path_provider / device_info_plus /
  // file_picker / sqflite / 视频播放)在本项目的 Windows 依赖集中没有原生实现,保留现状。
});
```

### 9.3 Linux：`my_application.cc`

当前注册 4 个插件（含 url_launcher）。`TrayManagerPlugin` 同样不注册：其 Linux 实现
用进程级全局 `plugin_instance` 记录最后注册的插件对象，子窗口注册会把它顶掉，子窗口
关闭后点击托盘菜单会用已释放的指针发事件，直接崩溃：

```cpp
desktop_multi_window_plugin_set_window_created_callback([](FlPluginRegistry* registry){
  // flutter_webrtc / window_manager / screen_retriever / url_launcher(不注册 tray_manager)
  g_autoptr(FlPluginRegistrar) url_launcher_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
  url_launcher_plugin_register_with_registrar(url_launcher_registrar);
  // 统一清单中其余插件在本项目的 Linux 依赖集中没有原生实现,保留现状。
});
```

另外，本文件还负责 Linux 主窗口标题：「野火IM」（GNOME HeaderBar 与传统标题栏
两处均设置，不再是模板硬编码的 "chat"）。

### 9.4 注册原则

- 所有子窗口 Dart 代码可能调用的**原生插件**都要注册；判断标准是对应平台的
  `generated_plugin_registrant.cc`（Windows/Linux）里存在该插件——只有存在，
  其注册函数/头文件才可链接。
- `shared_preferences`、`path_provider`、`device_info_plus`、`file_picker` 在
  Windows/Linux 上是**纯 Dart 实现**（`.flutter-plugins-dependencies` 中
  `native_build=false`，经 `dart_plugin_registrant` 在每个引擎自动注册，
  子窗口引擎复用同一 entrypoint 也会执行），不需要、也不可能在原生回调里注册。
- `sqflite` 和视频播放（本项目为 macOS 的 `FVPVideoPlayerPlugin`）在 Windows/Linux
  的依赖集中没有对应实现，保留现状；子窗口在这些平台上若用到相关能力需要另行评估。
- 如果后续遇到 `MissingPluginException`，把对应插件从 `generated_plugin_registrant.*` 抄到子窗口回调即可。

---

## 10. 窗口生命周期管理

### 10.1 创建与就绪

`CallWindowManager`（基于公共层 `SubWindowManagerBase`，reusePolicy = recreate，
见 §4.4）封装了子窗口创建：

```dart
class CallWindowManager extends SubWindowManagerBase {
  Future<int> createCallWindow({
    required String type,
    required VoidCallback onReady,
    required VoidCallback onClose,
    Map<String, dynamic>? arguments,
  });
}
```

- 全局最多一个通话窗口：再次创建先关旧窗再开新窗；
- 创建后返回 `windowId`；创建参数注入 `kWindowKindKey: 'call'`、`_windowType`、`_selfUserId`；
- 子窗口初始化完成后，通过 `MainWindowEvents.voipStatusChanged`（`{status:'ready', windowId}`）
  通知主窗口（通话窗的就绪/关闭**不**走公共层 `<kind>.ready` / `<kind>.windowClosed`
  约定，由 `MainAvEngineKitProxy` 路由到 `onCallWindowReady` / `onCallWindowClosed`）；
- 主窗口收到 ready 后把 `onReady` 回调触发，并刷新之前积压的事件队列。

### 10.2 事件队列

主窗口可能在子窗口还没 ready 时就收到 IM 消息（如来电刚弹窗时）。`MainAvEngineKitProxy` 内部维护 `_eventQueue`：

```dart
void _emitToCallWindow(String event, dynamic args) {
  if (_callWindowReady && _callWindowId != null) {
    WindowEventChannel.invoke(_callWindowId!, event, args);
  } else {
    _eventQueue.add(_QueuedEvent(event, args));
  }
}
```

子窗口 ready 后，`_flushEventQueue()` 把队列里的消息按顺序发给子窗口。

### 10.3 关闭与清理

子窗口关闭时触发 `onClose`：

```dart
void _onCallWindowClosed() {
  _callWindowId = null;
  _callWindowReady = false;
  _eventQueue.clear();
}
```

主窗口释放对子窗口的引用；下次通话会重新创建窗口。

---

## 11. 与移动端方案的差异

| 方面 | 移动端 | PC 独立窗口 |
|------|--------|------------|
| `Imclient` | 直接初始化真实连接 | 主窗口真实，子窗口代理 |
| `AVEngineKit` | 与 UI 同 isolate | 运行在子窗口 isolate |
| 通话 UI | 路由跳转 | 独立窗口 |
| 消息传递 | 直接 EventBus | 跨窗口 MethodChannel |
| 用户数据 | 共享内存 | 序列化后 IPC |
| 插件注册 | 自动 | 子窗口需手动注册（纯 Dart 插件除外，见 §9.4） |

桌面/移动分流与"通话进行中"判断收敛在唯一入口 `chat/lib/call/av_call_launcher.dart`
(`startAvCall` / `startSingleAvCall` / `startAvCallWithParticipants`),业务代码不再
自行写 `isDesktopShell ? proxy : avEngineKit` 分支:

```dart
// av_call_launcher.dart 内部
if (isDesktopShell) {
  MainAvEngineKitProxy.instance.startCall(conversation, participants, audioOnly);
} else {
  avEngineKit.startCall(conversation, participants, audioOnly);
}
```

---

## 12. 常见问题与排查

### 12.1 子窗口弹不出 / 白屏 / 崩溃

- 检查 `main.dart` 是否正确解析 `args[0] == 'multi_window'`，以及创建参数的
  `kWindowKindKey` 是否分发到了预期的 WindowApp（未携带 kind 会按历史兼容落到
  `CallWindowApp`，未知 kind 有 `debugPrint` 日志）；
- 检查子窗口入口是否使用 `SubWindowWidgetsBinding`（macOS 生命周期错误会导致停帧黑屏）；
- 检查子窗口插件是否都已在原生入口注册；
- 检查子窗口 App 的 Provider / ViewModel 是否已正确初始化。

### 12.2 `MissingPluginException`

日志里出现 `No implementation found for method xxx on channel yyy`：

- 确认该方法对应的插件已在 `MainFlutterWindow.swift` / `flutter_window.cpp` / `my_application.cc` 的子窗口回调中注册；
- 若在 Windows/Linux 上遇到，先确认该插件在该平台有原生实现（见 §9.4）——纯 Dart 实现的插件不需要注册；
- 修改原生代码后必须重新 `pod install` / `flutter build`。

### 12.3 头像/图片不显示

- 大概率是 `sqflite` 或 `path_provider` 没注册，导致 `CachedNetworkImage` 的 `flutter_cache_manager` 初始化失败；
- 检查 `_targetUserInfo?.portrait` 是否为空；
- 检查 `MediaUrlRedirector` 是否把头像 URL 转错了。

### 12.4 消息到了子窗口但解析失败

- 检查 `VoipMessageCodec.decodeMessage` 的 key 是否与主窗口 `MainAvEngineKitProxy._messageToJson` 一致；
- 检查 `binaryContent` 类型（`Uint8List` / `List<int>` / base64 字符串）是否都被兼容。

### 12.5 子窗口收不到 IM 消息

- 检查主窗口是否已 `install()` `MainAvEngineKitProxy`；
- 检查 `RawVoipMessageContent` 是否已注册对应的 VOIP 消息类型；
- 检查主窗口的 `_eventBus` 订阅是否已建立。

### 12.6 事件被错误的 handler 处理 / handler 丢失

- `WindowEventChannel` 的 handler 表是 isolate 内全局共享的，检查是否有两个功能
  注册了同名 method（重复注册会有 `debugPrint` 告警日志，见 §3.2）；
- 新增事件务必遵守 `<domain>[.imclient].<method>` 前缀约定。

---

## 13. 扩展建议

1. **统一 IPC 错误处理**：当前各 handler 自己 try/catch，可以封装一个统一的 `invokeSafely`，把子窗口调用失败时返回标准错误码。
2. **心跳/保活**：如果未来需要让通话窗口在后台持续运行，可以增加主窗口 ↔ 子窗口心跳，检测子窗口是否卡死。
3. **多通话窗口**：当前设计只维护一个 Call 窗口（recreate 策略）。如果需要同时支持多个通话（如一个会议 + 一个单聊），需要把 `windowId` 按 `conversation` / `callId` 索引。
4. **通话窗事件名向公共层约定靠拢**：通话窗的 ready/closed 走 `voip.statusChanged` /
   `voip.windowClosed`，与公共层 `<kind>.ready` / `<kind>.windowClosed` 约定不一致
   （因此 `CallWindowManager` 覆写了 `registerManagerHandlers` 为空，由
   `MainAvEngineKitProxy` 手工路由）。后续可以统一，去掉这个特例。
5. **Windows/Linux 新插件**：后续若子窗口引入新的原生插件（如截图、通知），先确认
   对应平台 `generated_plugin_registrant.cc` 中存在该插件，再同步更新子窗口注册代码。

---

## 14. 关键文件索引

### 公共层（`chat/lib/pc/multi_window/`）

| 文件 | 作用 |
|------|------|
| `window_event_channel.dart` | 跨窗口事件通道封装（isolate 单例、重复注册告警、`<domain>[.imclient].<method>` 约定） |
| `window_kind.dart` | `kWindowKindKey` + 四个窗口种类常量 |
| `sub_window_binding.dart` | 子窗口专用 Binding（macOS 生命周期降级，帧调度常开） |
| `sub_window_app_base.dart` | 子窗口 App 模板 mixin（init/标题/主题/关窗样板 + 模板方法钩子） |
| `sub_window_manager_base.dart` | 主窗口侧 Manager 基类（创建序列、ready/closed、三种 reusePolicy） |
| `proxy_imclient_channel.dart` | 子窗口 IM 代理通道基类（声明式方法表） |
| `proxy_completer.dart` | 主窗口侧 callback API → Future(`{errorCode, ...}`) 包装 |
| `ipc_codec.dart` | 跨窗口线格式唯一定义处(Message/Payload/Conversation ⇄ Map) |

### 通话窗口（`chat/lib/pc/call_window/`）

| 文件 | 作用 |
|------|------|
| `call_window_app.dart` | 子窗口根 Widget（基于 SubWindowAppBase），初始化 avenginekit，把主窗口事件 fire 到子窗口 IMEventBus |
| `call_window_manager.dart` | 创建/管理通话窗（基于 SubWindowManagerBase，recreate 策略，类型尺寸表） |
| `call_window_events.dart` | 通话窗事件名常量（`CallWindowEvents` voip.* / `MainWindowEvents` imclient.*） |
| `main_avengine_kit_proxy.dart` | 主窗口代理：监听 IM、转发事件、代发消息、回传发送结果、路由 ready/closed |
| `call_window_imclient_channel.dart` | 子窗口 IM 代理（基于 ProxyImclientChannel，14 个方法） |
| `voip_message_codec.dart` | 子窗口按 contentType 实例化 avenginekit 消息内容类 |
| `raw_voip_message_content.dart` | 主窗口占位 VOIP 消息内容类 |
| `model_codec.dart` | 用户/群成员信息编码(proto 形态,子窗口用 SDK 转换器解码) |

### 媒体预览窗口（`chat/lib/pc/media_preview_window/`）

| 文件 | 作用 |
|------|------|
| `media_preview_window_app.dart` | 预览窗子窗口 App（基于 SubWindowAppBase，强制暗色，不连 IM） |
| `media_preview_window_manager.dart` | 主窗口侧 Manager（尺寸自适应、pending show、代查 loadMore） |
| `media_preview_ipc.dart` | `MediaPreviewEvents` 事件名 + `MediaPreviewCodec`（基于 IpcCodec） |

### 朋友圈窗口（`chat/lib/pc/moment_window/`）

| 文件 | 作用 |
|------|------|
| `moment_window_app.dart` | 朋友圈子窗口 App（基于 SubWindowAppBase） |
| `moment_window_manager.dart` | 主窗口侧 Manager（raiseOnly 复用，notifyFeedChanged） |
| `moment_window_imclient_channel.dart` | 子窗口 IM 代理（前缀 `moment.imclient`，9 个方法） |
| `main_moment_proxy.dart` | 主窗口代理（代执行 IM 调用、转发 feed 刷新，用 ProxyCompleter） |
| `moment_ipc.dart` | `MomentWindowEvents` / `MomentMainEvents` 事件名 |

### 会话搜索窗口（`chat/lib/pc/search_window/`）

| 文件 | 作用 |
|------|------|
| `search_window_app.dart` | 搜索子窗口 App（基于 SubWindowAppBase，标准标题栏） |
| `search_window_manager.dart` | 主窗口侧 Manager（updateContent 复用，close） |
| `search_window_imclient_channel.dart` | 子窗口 IM 代理（前缀 `search.imclient`，9 个方法） |
| `main_search_proxy.dart` | 主窗口代理（代执行 IM 调用、定位消息跳回主窗口，用 ProxyCompleter） |
| `search_window_ipc.dart` | `SearchWindowEvents` / `SearchMainEvents` 事件名 + 创建参数编解码 |

### 其它

| 文件 | 作用 |
|------|------|
| `chat/lib/main.dart` | 子窗口入口 `args[0] == 'multi_window'`，按 `kWindowKindKey` 分发四类 WindowApp；主窗口安装 `MainAvEngineKitProxy` / `MainMomentProxy` / `MainSearchProxy` |
| `chat/lib/call/av_call_launcher.dart` | 发起音视频通话的唯一入口(桌面/移动分流 + 通话中判断) |
| `chat/lib/widget/watermark_overlay.dart` | 全局安全水印（主窗口与四类子窗口统一覆盖，用户 ID + 分钟精度时间，`Config.ENABLE_WATER_MARKER` 开关） |
| `chat/lib/pc/widgets/pc_window_caption.dart` | Windows 主窗口自绘标题栏（配合 `PCWindowManager.ensureInitialized()` 的 `setTitleBarStyle(hidden)`；子窗口不使用） |
| `imclient/lib/imclient_method_channel.dart` | `dispatchSendMessageResult` / `dispatchConferenceRequestResult` / `dispatchStringResult` / `dispatchOperationResult`（子窗口代理回调分发） |
| `chat/macos/Runner/MainFlutterWindow.swift` | macOS 主窗口 + 子窗口插件注册（9 个，无 tray_manager） |
| `chat/windows/runner/flutter_window.cpp` | Windows 主窗口 + 子窗口插件注册（5 个，含 url_launcher，不含 tray_manager） |
| `chat/linux/runner/my_application.cc` | Linux 主窗口（标题「野火IM」）+ 子窗口插件注册（4 个，含 url_launcher，不含 tray_manager） |
