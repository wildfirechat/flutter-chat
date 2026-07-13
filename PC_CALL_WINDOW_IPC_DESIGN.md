# PC 端音视频通话独立窗口 IPC 方案设计文档

## 1. 背景与目标

### 1.1 为什么需要独立窗口？

在移动端，音视频通话界面通常以全屏路由的形式覆盖在主界面上。PC 端（macOS/Windows/Linux）则不同：

- 用户希望在通话的同时继续操作聊天主窗口；
- 通话窗口需要独立的标题栏、尺寸、置顶状态；
- 音视频引擎（WebRTC）持有独立的渲染上下文，放在独立 Engine 里更安全。

因此，PC 端采用「**主窗口负责 IM，通话子窗口负责音视频引擎 + UI**」的架构。

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

### 3.2 封装：`CallWindowEventChannel`

文件：`chat/lib/pc/call_window/call_window_event_channel.dart`

为了避免主窗口和子窗口直接依赖 `desktop_multi_window` 的 API 细节，项目封装了一个事件通道：

```dart
class CallWindowEventChannel {
  /// 主窗口调用：向指定子窗口发送事件。
  static Future<dynamic> invoke(int windowId, String event, dynamic args);

  /// 任意窗口调用：设置当前窗口收到事件时的处理器。
  static void listen(Future<dynamic> Function(String event, dynamic args)? handler);
}
```

实现原理：

- 发送方把 `{event, args}` 通过 `DesktopMultiWindow.invokeMethod` 发到目标窗口；
- 接收方通过 `DesktopMultiWindow.setMethodHandler` 接收，解出 `event`，调用业务注册的 `handler`。

这样主窗口和子窗口之间传输的是「事件名 + 序列化参数」，而不是裸的 `MethodCall`。

---

## 4. 事件协议

### 4.1 主窗口 → 子窗口（下行事件）

主窗口在 `MainAvEngineKitProxy` 中定义了子窗口需要监听的事件：

```dart
class CallWindowEvents {
  static const String startCall = 'startCall';
  static const String message = 'message';
  static const String conferenceEvent = 'conferenceEvent';
  static const String connectionStatus = 'connectionStatus';
  static const String ready = 'ready';
}
```

| 事件 | 触发时机 | 参数 | 子窗口处理 |
|------|---------|------|-----------|
| `startCall` | 用户主动发起通话 | 会话、selfUserId、participants、audioOnly 等 | 初始化 CallSession 并进入 Outgoing 状态 |
| `message` | 主窗口收到 VOIP 相关 IM 消息 | 序列化的 `Message` | 交给 `AVEngineKit.onReceiveMessages` |
| `conferenceEvent` | 主窗口收到会议事件 | 事件字符串 | 交给 `AVEngineKit.onConferenceEvent` |
| `connectionStatus` | IM 连接状态变化 | 状态码 | 子窗口可据此做重连/提示 |
| `ready` | 子窗口初始化完成通知主窗口后，主窗口回 ack | 无 | 触发事件队列刷新 |

### 4.2 子窗口 → 主窗口（上行调用）

子窗口在 `CallWindowImclientChannel` 中定义了需要主窗口代为执行的 IM 操作：

```dart
class MainWindowEvents {
  static const String sendMessage = 'imclient.sendMessage';
  static const String sendConferenceRequest = 'imclient.sendConferenceRequest';
  static const String getUserInfo = 'imclient.getUserInfo';
  static const String getUserInfos = 'imclient.getUserInfos';
  static const String getGroupMembers = 'imclient.getGroupMembers';
  static const String getMessageByUid = 'imclient.getMessageByUid';
  static const String updateMessage = 'imclient.updateMessage';
}
```

| 调用 | 用途 | 返回 |
|------|------|------|
| `sendMessage` | 子窗口让主窗口发送 VOIP 信令消息 | 序列化后的 Message |
| `sendConferenceRequest` | 子窗口让主窗口发送会议请求 | HTTP 结果字符串 |
| `getUserInfo` / `getUserInfos` | 获取远端用户头像/昵称 | 序列化后的 UserInfo 列表 |
| `getGroupMembers` | 多人通话获取群成员信息 | 序列化后的 GroupMember 列表 |
| `getMessageByUid` | 查询已发送信令消息 | 序列化后的 Message |
| `updateMessage` | 更新本地通话记录消息 | 无 |

---

## 5. 数据序列化

主窗口和子窗口运行在不同 isolate，所有跨窗口传递的对象必须序列化为 `Map<String, dynamic>` 或 JSON。

### 5.1 VOIP 消息：`VoipMessageCodec`

文件：`chat/lib/pc/call_window/voip_message_codec.dart`

`Message` 和 `MessageContent` 没有内置的跨 isolate 序列化能力。`VoipMessageCodec` 只处理 avenginekit 关心的 VOIP 消息类型：

```dart
class VoipMessageCodec {
  static Map<String, dynamic> encodeMessage(Message message);
  static Message decodeMessage(Map<String, dynamic> map);
  static MessageContent decodeMessageContent(Map<String, dynamic> map);
}
```

编码后的消息结构：

```json
{
  "messageId": 123,
  "messageUid": 456,
  "conversation": {"conversationType": 0, "target": "userId", "line": 0},
  "fromUser": "userId",
  "toUsers": ["userId"],
  "direction": 0,
  "status": 0,
  "serverTime": 1783927749301,
  "localExtra": null,
  "content": {
    "contentType": 400,
    "searchableContent": "...",
    "binaryContent": "base64...",
    ...
  }
}
```

注意：

- 编码时用 `'content'` 作为 payload key；解码时同时兼容 `'content'` 和 `'payload'`；
- `binaryContent` 在编码时做 base64，解码时支持 `Uint8List`、`List<int>`（MethodChannel 透传后常被重新实例化为 `_GrowableList`）和 base64 字符串；
- `contentType` 兼容 `type` 别名，并做 `?? 0` 兜底。

### 5.2 主窗口占位 VOIP 消息：`RawVoipMessageContent`

文件：`chat/lib/pc/call_window/raw_voip_message_content.dart`

主窗口不需要理解 VOIP 业务，只要能把收到的 VOIP 消息原样透传给子窗口。`RawVoipMessageContent` 是一个通用占位内容类：

- 注册正确的 `MessageFlag`（是否持久、是否计数），让 IM SDK 对 incoming VOIP 消息的处理与 avenginekit 一致；
- 把 `MessagePayload` 按字段原样保存；
- `encode()` 时把 payload 返回给主窗口代理，代理再交给 `VoipMessageCodec` 编码传给子窗口。

### 5.3 用户/群成员信息：`ModelCodec`

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

## 6. IM 代理机制详解

### 6.1 子窗口侧：`CallWindowImclientChannel`

文件：`chat/lib/pc/call_window/call_window_imclient_proxy.dart`

子窗口启动时，会执行 `Imclient.init(...)`，但这里把 `ImclientPlatform.instance.channel` 替换为一个代理通道：

```dart
class CallWindowImclientChannel extends ImclientChannel {
  @override
  Future<dynamic> invokeMethod(String method, [dynamic arguments]) async {
    // 把 IM 方法调用转发到主窗口
    final result = await CallWindowEventChannel.invoke(_mainWindowId, _mapMethod(method), arguments);
    // 对结果做类型转换，让上层 Imclient 接口无感知
    return _adaptResult(method, result);
  }
}
```

这样，子窗口里的 `Imclient.sendMessage(...)`、`Imclient.getUserInfo(...)` 等调用，实际上都通过 IPC 发到了主窗口。

### 6.2 主窗口侧：`MainAvEngineKitProxy`

文件：`chat/lib/pc/call_window/main_avengine_kit_proxy.dart`

主窗口在 `install()` 时：

1. 注册 `RawVoipMessageContent` 占位所有 VOIP 消息类型；
2. 监听 `ReceiveMessagesEvent`、`ConferenceEvent`、`ConnectionStatusChangedEvent`；
3. 设置子窗口事件处理器，处理子窗口发回的 IM 代理调用；
4. 初始化 `CallWindowEventChannel`。

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

### 6.3 为什么不能让子窗口直接连接 IM？

项目中的 `Imclient` 底层依赖 `libMarsWrapper` / Mars，通常一个进程只允许一个连接。如果子窗口也尝试初始化真实 IM 连接，会：

- 与主窗口抢占连接，导致主窗口掉线；
- 状态不一致（两个 isolate 各自维护消息状态）；
- 增加复杂度（需要处理双端消息同步）。

所以子窗口只做「代理调用者」，真实 IM 能力集中在主窗口。

---

## 7. 通话生命周期中的 IPC 流程

### 7.1 主动发起通话

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
  - 通知主窗口 ready
        │
        ▼
主窗口收到 ready，把初始 startCall 事件发给子窗口
        │
        ▼
子窗口 AVEngineKitImpl.startCall() → 创建房间 → 通过代理 sendMessage 发 START 信令
```

### 7.2 收到来电

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

### 7.3 通话中交换信令

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

## 8. 子窗口原生插件注册

子窗口是独立的 Flutter Engine，桌面端不会自动继承主窗口的插件注册表。因此必须在每个平台的窗口入口里手动注册子窗口可能用到的插件。

### 8.1 macOS：`MainFlutterWindow.swift`

```swift
FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
  FlutterWebRTCPlugin.register(with: controller.registrar(forPlugin: "FlutterWebRTCPlugin"))
  WindowManagerPlugin.register(with: controller.registrar(forPlugin: "WindowManagerPlugin"))
  TrayManagerPlugin.register(with: controller.registrar(forPlugin: "TrayManagerPlugin"))
  SharedPreferencesPlugin.register(with: controller.registrar(forPlugin: "SharedPreferencesPlugin"))
  PathProviderPlugin.register(with: controller.registrar(forPlugin: "PathProviderPlugin"))
  DeviceInfoPlusMacosPlugin.register(with: controller.registrar(forPlugin: "DeviceInfoPlusMacosPlugin"))
  SqflitePlugin.register(with: controller.registrar(forPlugin: "SqflitePlugin"))
}
```

### 8.2 Windows：`flutter_window.cpp`

```cpp
DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
  auto* registry = reinterpret_cast<flutter::FlutterViewController*>(controller)->engine();
  FlutterWebRTCPluginRegisterWithRegistrar(registry->GetRegistrarForPlugin("FlutterWebRTCPlugin"));
  WindowManagerPluginRegisterWithRegistrar(registry->GetRegistrarForPlugin("WindowManagerPlugin"));
  TrayManagerPluginRegisterWithRegistrar(registry->GetRegistrarForPlugin("TrayManagerPlugin"));
  ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(registry->GetRegistrarForPlugin("ScreenRetrieverWindowsPluginCApi"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
});
```

### 8.3 Linux：`my_application.cc`

```cpp
desktop_multi_window_plugin_set_window_created_callback([](FlPluginRegistry* registry){
  // ... webrtc / window_manager / tray_manager ...
  g_autoptr(FlPluginRegistrar) screen_retriever_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "ScreenRetrieverLinuxPlugin");
  screen_retriever_linux_plugin_register_with_registrar(screen_retriever_registrar);
});
```

### 8.4 注册原则

- 所有子窗口 Dart 代码可能调用的**原生插件**都要注册；
- `shared_preferences`、`path_provider`、`device_info_plus` 在 Windows/Linux 是 `dartPluginClass`（纯 Dart + FFI），不需要手动注册原生插件；
- `sqflite` 只在 macOS/iOS/Android 有原生实现，Windows/Linux 上没有对应实现，因此不需要注册；
- 如果后续遇到 `MissingPluginException`，把对应插件从 `generated_plugin_registrant.*` 抄到子窗口回调即可。

---

## 9. 窗口生命周期管理

### 9.1 创建与就绪

`CallWindowManager` 封装了子窗口创建：

```dart
class CallWindowManager {
  Future<int> createCallWindow({
    required String type,
    required VoidCallback onReady,
    required VoidCallback onClose,
  });
}
```

- 创建后返回 `windowId`；
- 子窗口初始化完成后，通过 `CallWindowEvents.ready` 通知主窗口；
- 主窗口收到 ready 后把 `onReady` 回调触发，并刷新之前积压的事件队列。

### 9.2 事件队列

主窗口可能在子窗口还没 ready 时就收到 IM 消息（如来电刚弹窗时）。`MainAvEngineKitProxy` 内部维护 `_eventQueue`：

```dart
void _emitToCallWindow(String event, dynamic args) {
  if (_callWindowReady && _callWindowId != null) {
    CallWindowEventChannel.invoke(_callWindowId!, event, args);
  } else {
    _eventQueue.add(_QueuedEvent(event, args));
  }
}
```

子窗口 ready 后，`_flushEventQueue()` 把队列里的消息按顺序发给子窗口。

### 9.3 关闭与清理

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

## 10. 与移动端方案的差异

| 方面 | 移动端 | PC 独立窗口 |
|------|--------|------------|
| `Imclient` | 直接初始化真实连接 | 主窗口真实，子窗口代理 |
| `AVEngineKit` | 与 UI 同 isolate | 运行在子窗口 isolate |
| 通话 UI | 路由跳转 | 独立窗口 |
| 消息传递 | 直接 EventBus | 跨窗口 MethodChannel |
| 用户数据 | 共享内存 | 序列化后 IPC |
| 插件注册 | 自动 | 子窗口需手动注册 |

移动端代码通过 `isDesktopShell` 分支判断走哪条路：

```dart
if (isDesktopShell) {
  MainAvEngineKitProxy.instance.startCall(conversation, participants, audioOnly);
} else {
  avEngineKit.startCall(conversation, participants, audioOnly);
}
```

---

## 11. 常见问题与排查

### 11.1 子窗口弹不出 / 白屏 / 崩溃

- 检查 `main.dart` 是否正确解析 `args[0] == 'multi_window'`；
- 检查子窗口插件是否都已在原生入口注册；
- 检查 `CallWindowApp` 的 Provider / ViewModel 是否已正确初始化。

### 11.2 `MissingPluginException`

日志里出现 `No implementation found for method xxx on channel yyy`：

- 确认该方法对应的插件已在 `MainFlutterWindow.swift` / `flutter_window.cpp` / `my_application.cc` 的子窗口回调中注册；
- 修改原生代码后必须重新 `pod install` / `flutter build`。

### 11.3 头像/图片不显示

- 大概率是 `sqflite` 或 `path_provider` 没注册，导致 `CachedNetworkImage` 的 `flutter_cache_manager` 初始化失败；
- 检查 `_targetUserInfo?.portrait` 是否为空；
- 检查 `MediaUrlRedirector` 是否把头像 URL 转错了。

### 11.4 消息到了子窗口但解析失败

- 检查 `VoipMessageCodec.decodeMessage` 的 key 是否与主窗口 `MainAvEngineKitProxy._messageToJson` 一致；
- 检查 `binaryContent` 类型（`Uint8List` / `List<int>` / base64 字符串）是否都被兼容。

### 11.5 子窗口收不到 IM 消息

- 检查主窗口是否已 `install()` `MainAvEngineKitProxy`；
- 检查 `RawVoipMessageContent` 是否已注册对应的 VOIP 消息类型；
- 检查主窗口的 `_eventBus` 订阅是否已建立。

---

## 12. 扩展建议

1. **统一 IPC 错误处理**：当前各 handler 自己 try/catch，可以封装一个统一的 `invokeSafely`，把子窗口调用失败时返回标准错误码。
2. **心跳/保活**：如果未来需要让通话窗口在后台持续运行，可以增加主窗口 ↔ 子窗口心跳，检测子窗口是否卡死。
3. **多通话窗口**：当前设计只维护一个 `_callWindowId`。如果需要同时支持多个通话（如一个会议 + 一个单聊），需要把 `windowId` 按 `conversation` / `callId` 索引。
4. **Windows/Linux 插件补齐**：后续若子窗口引入新的原生插件（如文件选择、截图、通知），需要同步更新三个平台的子窗口注册代码。

---

## 13. 关键文件索引

| 文件 | 作用 |
|------|------|
| `chat/lib/main.dart` | 子窗口入口 `args[0] == 'multi_window'`；安装 `MainAvEngineKitProxy` |
| `chat/lib/pc/call_window/call_window_app.dart` | 子窗口根 Widget，初始化代理和 avenginekit |
| `chat/lib/pc/call_window/call_window_manager.dart` | 创建/管理子窗口 |
| `chat/lib/pc/call_window/call_window_event_channel.dart` | 跨窗口事件通道封装 |
| `chat/lib/pc/call_window/main_avengine_kit_proxy.dart` | 主窗口代理：监听 IM、转发事件、代发消息 |
| `chat/lib/pc/call_window/call_window_imclient_proxy.dart` | 子窗口 IM 代理：把 IM 调用转发给主窗口 |
| `chat/lib/pc/call_window/voip_message_codec.dart` | VOIP 消息跨窗口编解码 |
| `chat/lib/pc/call_window/raw_voip_message_content.dart` | 主窗口占位 VOIP 消息内容类 |
| `chat/lib/pc/call_window/model_codec.dart` | 用户/群成员信息跨窗口编解码 |
| `chat/macos/Runner/MainFlutterWindow.swift` | macOS 主窗口 + 子窗口插件注册 |
| `chat/windows/runner/flutter_window.cpp` | Windows 主窗口 + 子窗口插件注册 |
| `chat/linux/runner/my_application.cc` | Linux 主窗口 + 子窗口插件注册 |
