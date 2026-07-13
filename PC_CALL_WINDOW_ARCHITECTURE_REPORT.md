# PC 端音视频通话独立窗口实现报告

## 1. 概述

本报告分析 `vue-pc-chat`（Electron PC 平台）的音视频通话多窗口实现方式，并给出可借鉴到当前 Flutter 桌面项目的架构方案。

**核心结论**：
- Electron 版的实现是「**主窗口持有 IM 和代理（AvEngineKitProxy），通话窗口只跑音视频引擎和 UI**」。
- 该模式可以直接映射到 Flutter 桌面：**主窗口用真实 `Imclient`，通话窗口用 `ImclientProxy` 通过窗口间通信转发 IM 调用**。
- 在 Flutter 中实现的关键难点不是 UI，而是 **isolate 隔离带来的 IM/音视频状态共享问题**。

---

## 2. vue-pc-chat / avenginekit.js 的 Electron 实现

### 2.1 总体架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Electron 主进程                              │
│  • 创建/管理 BrowserWindow                                            │
│  • 路由 IPC：voip-message / conference-request / webcontents-send     │
│  • 屏幕捕获权限、截图、通知等原生能力                                   │
└─────────────────────────────────────────────────────────────────────┘
       ▲                                               │
       │                                               │
       │ IPC                                           │ webContents.send
       │                                               │
┌──────┴──────────────────┐              ┌─────────────▼──────────────────┐
│      主窗口渲染进程        │              │        通话窗口渲染进程         │
│                         │              │                                │
│  • Vue UI（聊天列表等）    │              │  • Voip UI（Single/Multi/Conf）│
│  • wfc / Imclient        │              │  • avenginekit.js (engine.min) │
│  • AvEngineKitProxy      │◄────────────►│  • WebRTC 会话管理              │
│    - 监听 IM 消息/会议事件 │  IPC 转发    │                                │
│    - 创建通话窗口         │              │                                │
│    - 代发 IM 消息/会议请求 │              │                                │
└─────────────────────────┘              └────────────────────────────────┘
```

### 2.2 关键角色

#### 2.2.1 `AvEngineKitProxy`（主窗口）

文件：`src/wfc/av/engine/avenginekitproxy.js`

这是整个通话流程的「总控」，常驻于主窗口渲染进程：

1. **初始化时注册 IM 事件监听**
   ```js
   this.event.on(EventType.ReceiveMessage, this.onReceiveMessage);
   this.event.on(EventType.ConferenceEvent, this.onReceiveConferenceEvent);
   this.event.on(EventType.ConnectionStatusChanged, this.onConnectionStatusChange);
   ```

2. **收到通话消息后决定弹出通话窗口**
   - 收到 `VOIP_CONTENT_TYPE_START` / `VOIP_CONTENT_TYPE_ADD_PARTICIPANT` 等消息时，组装 `selfUserInfo`、`participantUserInfos`、`groupMemberUserInfos`。
   - 调用 `showCallUI(conversation, isConference, options)` 创建通话窗口。

3. **把 IM 事件转发到通话窗口**
   ```js
   emitToVoip(event, args) {
       if (this.isVoipWindowReady) {
           this.callWin.webContents.send(event, JSON.stringify(args));
       } else {
           this.queueEvents.push({event, args});
       }
   }
   ```
   转发的事件包括：`message`、`conferenceEvent`、`connectionStatus`。

4. **代通话窗口执行 IM 操作**
   通话窗口通过 IPC 发回：
   - `voip-message` → `AvEngineKitProxy.sendVoipListener()` → `wfc.sendConversationMessage()`
   - `conference-request` → `AvEngineKitProxy.sendConferenceRequestListener()` → `wfc.sendConferenceRequestEx()`
   - `update-call-start-message` → 更新本地通话记录消息

5. **管理通话窗口生命周期**
   - `startCall()` / `startConference()` / `joinConference()`：创建窗口并传入初始事件。
   - `onVoipWindowClose()`：窗口关闭后清理 `conversation`、`callId`、`participants`、事件队列。

#### 2.2.2 Electron 主进程窗口管理

文件：`src/background.js`

```js
ipcMain.handle('create-voip-window', async (event, windowOptions) => {
    const win = new BrowserWindow(windowOptions);
    win.on('closed', () => {
        event.sender.send(`voip-window-closed`);
    });
    win.webContents.on('did-finish-load', () => {
        event.sender.send(`voip-window-webContents-did-finish-load`);
    });
    win.loadURL(windowOptions.url);
    return win.id;
});

ipcMain.on('voip-message', (event, args) => {
    mainWindow.webContents.send('voip-message', args);
});
ipcMain.on('conference-request', (event, args) => {
    mainWindow.webContents.send('conference-request', args);
});
```

主进程只做三件事：创建窗口、把通话窗口的消息转发给主窗口、把窗口生命周期事件回传。

#### 2.2.3 通话窗口（Voip UI）

文件：`src/ui/voip/Single.vue`、`Multi.vue`、`conference/Conference.vue`

- 每个通话窗口是一个独立的 Vue 应用实例，路由到 `/voip/single`、`/voip/multi`、`/voip/conference`。
- 内部运行 `avenginekit.js` 的真实实现（`engine.min.js`）。
- 通过 `CallSessionCallback` 更新 UI（状态、本地/远端视频流、时长等）。
- 需要发信令时，通过内部事件总线触发 `voip-message` / `conference-request`，经主进程回到 `AvEngineKitProxy`。

#### 2.2.4 跨窗口通信方式

Electron 版使用了**两套**跨窗口机制：

1. **主进程 IPC**：用于主窗口 ↔ 通话窗口的有状态通信（创建窗口、转发消息）。
2. **`localStorageEmitter`**：用于同域下多个 BrowserWindow 之间的轻量广播，例如从通话窗口发起「开始另一个通话」时通知主窗口处理。
   文件：`src/ipc/localStorageEmitter.js`
   ```js
   // 基于 window.addEventListener('storage') 的跨标签页通信
   localStorageEmitter.send('startVoipCall', {conversation, audioOnly});
   ```

### 2.3 通话启动流程

以主窗口发起单聊视频通话为例：

1. 用户点击通话按钮 → `Voip.js` 调用 `avenginekitproxy.startCall(conversation, audioOnly, [target])`。
2. `AvEngineKitProxy` 生成 `callId`，组装用户信息，调用 `showCallUI()`。
3. `showCallUI()` 通过 `BrowserWindow.new()` 让主进程创建 `/voip/single` 窗口。
4. 窗口加载完成后，主进程发回 `voip-window-webContents-did-finish-load`。
5. `AvEngineKitProxy` 把 `startCall` 事件（含 conversation、callId、participantUserInfos 等）通过 `webContents.send` 发给通话窗口。
6. 通话窗口的 `engine.min.js` 收到 `startCall`，创建 `CallSession`，开始 WebRTC 协商、发 `CallStartMessage`。
7. 通话窗口发信令时触发 `voip-message` → 主进程 → 主窗口 `AvEngineKitProxy` → `wfc.sendConversationMessage()`。

来电流程类似，只是第 5 步转发的是 `message` 事件（包含 `VOIP_CONTENT_TYPE_START`）。

### 2.4 窗口尺寸策略

`AvEngineKitProxy.showCallUI()` 中根据通话类型决定窗口大小：

| 类型 | 宽度 | 高度 | 备注 |
|---|---|---|---|
| single（单人） | 360 | 640 | 竖屏 |
| single-rc（远程控制） | 960 | 600 | 横屏 |
| multi（多人） | 960 | 640 | 横屏 |
| conference（会议） | 960 | 640 | 无边框、透明背景 |

屏幕共享时，会议窗口会缩小为控制条尺寸（约 420×140）。

---

## 3. 可借鉴到 Flutter 桌面的设计

### 3.1 Electron vs Flutter 桌面的本质差异

| 维度 | Electron | Flutter 桌面（desktop_multi_window） |
|---|---|---|
| 多窗口模型 | 同一进程，多个 **renderer 进程** 共享主进程 | 每个窗口是独立的 **Flutter Engine / Dart isolate** |
| JS 对象共享 | 不能跨 renderer，但可通过 IPC 快速传递对象引用 | 完全隔离，不能共享任何 Dart 对象 |
| IM 连接 | 主窗口 renderer 持有 `wfc` | 必须明确决定由哪个 isolate 持有 |
| 插件状态 | 插件在主进程初始化一次即可 | 每个窗口引擎需要单独注册插件 |
| 视频流 | HTMLVideoElement 可在同 renderer 内渲染 | `RTCVideoRenderer` 绑定创建它的 Engine |

因此 Flutter 不能简单照搬 Electron 的 IPC，需要把「IM 调用」抽象成可跨 isolate 转发的协议。

### 3.2 推荐的 Flutter 架构

直接借鉴 Electron 版的「主窗口代理 + 通话窗口自持引擎」模式：

```
┌──────────────────────────────────────────────────────────────────────┐
│                          主窗口 (Main Engine)                         │
│  • 真实 Imclient / IM 连接                                             │
│  • 真实 avenginekit? 不需要，改为 AvEngineKitProxy                     │
│  • 监听 ReceiveMessage / ConferenceEvent / ConnectionStatusChanged    │
│  • 创建/管理 Call 窗口                                                 │
│  • 执行 Call 窗口转发来的 sendMessage / sendConferenceRequest         │
│  • 把通话相关事件通过 WindowMethodChannel 发给 Call 窗口               │
└──────────────────────────────────────────────────────────────────────┘
                               WindowMethodChannel
                                    ▲                │
                                    │                │
                                    │                ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      通话窗口 (Call Engine)                           │
│  • ImclientProxy（把 Imclient 调用转发给主窗口）                        │
│  • avenginekit（真实音视频引擎）                                        │
│  • CallSession + VoipCallScreen / MultiCallScreen / ConferenceCallScreen│
│  • WebRTC 渲染                                                         │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.3 为什么让 Call 窗口持有 avenginekit

因为 `RTCVideoRenderer` / `MediaStream` 不能跨 Engine 共享。如果 avenginekit 放在主窗口，视频流无法直接渲染到 Call 窗口。

Call 窗口必须自己能跑 WebRTC，所以需要：
- 自己有一份 `avenginekit` 实例。
- 通过 `ImclientProxy` 让 avenginekit 以为自己能访问 IM，实际所有 IM 操作都转发给主窗口。

### 3.4 `ImclientProxy` 实现要点

`Imclient` 桌面端最终走 `ImclientChannel` 抽象：

```dart
abstract class ImclientChannel {
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]);
  void setMethodCallHandler(Future<dynamic> Function(MethodCall call)? handler);
}
```

在 Call 窗口启动时，把 `ImclientPlatform.instance` 替换为代理实现：

```dart
ImclientPlatform.instance = CallWindowImclientProxy();
```

代理的 `invokeMethod` 把所有调用序列化后通过 `WindowMethodChannel` 发给主窗口；主窗口执行真实 `Imclient` 并返回结果。

代理的 `setMethodCallHandler` 注册一个回调；当主窗口把 IM 事件（`ReceiveMessagesEvent`、`ConferenceEvent`、`ConnectionStatusChanged`）转发过来时，代理把它们还原成 `MethodCall` 喂给这个 handler，从而触发 Call 窗口里 `avenginekit` 的事件监听。

### 3.5 主窗口需要代理哪些 IM 方法

根据 `avenginekit` 实际调用，至少需要覆盖：

- **消息注册**：`registerMessageContent`（在主窗口注册所有通话消息类型）。
- **发送消息**：`sendMessage`、`sendConversationMessage`。
- **会议请求**：`sendConferenceRequest`、`sendConferenceRequestEx`。
- **用户信息**：`getUserInfo`、`getUserInfos`、`currentUserId`、`clientId`。
- **群信息**：`getGroupMemberIds`、`getGroupMembers`（多人通话需要）。
- **聊天室**：`joinChatroom`、`quitChatroom`（会议需要）。
- **消息查询/更新**：`getMessageByUid`、`updateMessageContent`（更新通话记录）。
- **连接状态**：`connectionStatus`、`isLogined`。

大部分方法是「转发-执行-返回」的无状态调用，实现成本可控。

### 3.6 事件转发协议（主窗口 → Call 窗口）

| 事件名 | 触发时机 | Call 窗口处理 |
|---|---|---|
| `startCall` | 主窗口主动发起通话 | 创建 outgoing CallSession |
| `startConference` | 主窗口创建会议 | 创建 conference CallSession |
| `joinConference` | 主窗口加入会议 | 创建 join Conference CallSession |
| `message` | 收到通话相关 IM 消息 | 交给 avenginekit 处理（来电、接听、信令等） |
| `conferenceEvent` | 收到会议事件 | 交给 avenginekit 处理 |
| `connectionStatus` | IM 连接状态变化 | 同步给 avenginekit |

这些事件可以直接对应 Electron 版 `AvEngineKitProxy.emitToVoip()` 转发的事件。

### 3.7 反向协议（Call 窗口 → 主窗口）

| 事件名 | 含义 | 主窗口处理 |
|---|---|---|
| `imclient.sendMessage` | 发送通话信令消息 | 调用 `Imclient.sendConversationMessage` |
| `imclient.sendConferenceRequest` | 发送会议请求 | 调用 `Imclient.sendConferenceRequestEx` |
| `imclient.updateMessageContent` | 更新通话记录消息 | 调用 `Imclient.updateMessageContent` |
| `imclient.getUserInfo` 等 | 查询类调用 | 调用对应 `Imclient` 方法并返回 |
| `voip.statusChanged` | 通话状态变化（可选） | 更新主窗口 UI、任务栏等 |
| `voip.windowClose` | 通话窗口关闭 | 清理 proxy 状态 |

### 3.8 Call 窗口生命周期

借鉴 Electron 版的按需创建模式：

1. **按需创建**：没有通话时不存在 Call 窗口，节省内存。
2. **创建时隐藏**：`WindowController.create(hiddenAtLaunch: true)`，等初始化完成后再 `show()`。
3. **关闭即销毁**：用户点关闭后销毁窗口；下次通话重新创建。
4. **（可选）保持隐藏**：如果希望复用窗口，可以在通话结束后 `hide()` 而不是 `close()`，但需要注意内存占用。

---

## 4. 实现步骤建议

### Phase 1：搭建多窗口骨架

- 引入 `desktop_multi_window`。
- 修改 `windows/runner/flutter_window.cpp`、`macos/Runner/MainFlutterWindow.swift`、`linux/my_application.cc` 注册插件回调。
- 实现主窗口「打开通话子窗口」按钮 demo，子窗口能显示/隐藏/关闭。

### Phase 2：实现 `ImclientProxy`

- 在 Call 窗口 Engine 中替换 `ImclientPlatform.instance`。
- 实现 `WindowMethodChannel` 双向通信：Call 窗口转发 `invokeMethod`，主窗口返回结果。
- 主窗口把 `currentUserId`、连接状态等基础信息同步给 Call 窗口。

### Phase 3：迁移 avenginekit 到 Call 窗口

- Call 窗口初始化 `avenginekit`。
- 主窗口收到通话消息后，通过 `WindowMethodChannel` 转发 `message` 事件到 Call 窗口。
- Call 窗口的 `avenginekit` 处理事件并创建 `CallSession`。
- 验证发送信令消息能回到主窗口并真正发出。

### Phase 4：完善 UI 和窗口管理

- 复用已有的 `VoipCallScreen`、`MultiCallScreen`、`ConferenceCallScreen` 到 Call 窗口。
- 根据通话类型设置窗口尺寸。
- 实现屏幕共享时的窗口尺寸变化。
- 处理关闭拦截：通话中点关闭应先 hangup，避免直接销毁。

### Phase 5：多人通话邀请、会议入口等高级功能

- 在 Call 窗口内实现邀请成员（从主窗口获取群成员列表）。
- 从发现页/群聊入口挂载会议创建/加入。
- 这些功能当前项目已有部分实现，可继续补齐。

---

## 5. 风险与注意事项

1. **插件注册**：`flutter_webrtc`、`window_manager` 等插件必须在 Call 窗口 Engine 中手动注册，否则 `RTCVideoRenderer` 初始化会失败。
2. **Isolate 状态隔离**：Call 窗口不能访问主窗口的 Provider/Store，所有状态必须通过协议传递。
3. **消息重复消费**：主窗口收到通话消息后，应避免自己再处理一遍（如显示通话记录弹窗），只负责转发。
4. **IM 连接断开**：如果主窗口 IM 断开，Call 窗口会同步收到 `connectionStatus` 事件，需要合理处理（通常通话也会随之结束）。
5. **窗口焦点/任务栏**：Call 窗口显示后需要获取焦点；会议窗口可能需要无边框+透明背景。
6. **资源释放**：Call 窗口销毁时，必须确保 `RTCVideoRenderer`、peer connection、`avenginekit` 会话都已释放，否则会造成内存/摄像头泄漏。
7. **WebRTC 在子窗口的兼容性**：需要验证 `flutter_webrtc` 在 `desktop_multi_window` 创建的子窗口中是否能正常获取摄像头/麦克风和建立 peer connection。

---

## 6. 总结

`vue-pc-chat` 的 Electron 实现已经给出了一条清晰的路：

> **主窗口做 IM 代理，通话窗口做音视频引擎和 UI，两者之间通过序列化事件通信。**

Flutter 桌面虽然 isolate 隔离更强，但 `desktop_multi_window` + `WindowMethodChannel` 足以复现这套模式。核心实现成本在于：

1. 把 `Imclient` 抽象成可在 Call 窗口代理的通道。
2. 定义清晰的主窗口 ↔ Call 窗口事件协议。
3. 保证每个窗口 Engine 正确注册 WebRTC 等插件。

建议下一步先做 Phase 1 的多窗口骨架 + Phase 2 的 `ImclientProxy` 最小 demo，验证「Call 窗口能转发一条 `sendMessage` 给主窗口并成功发送」后，再整体迁移 `avenginekit`。
