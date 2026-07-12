# iOS CallKit 功能说明与移植指南

本文档介绍当前 Flutter 项目里 iOS 端 CallKit 来电功能的设计、文件分布、运行流程、开关配置，以及如何把该功能移植到另一个 Flutter 项目。

---

## 目录

1. [功能概述](#功能概述)
2. [设计思路与核心文件](#设计思路与核心文件)
3. [运行流程](#运行流程)
4. [开启与关闭](#开启与关闭)
5. [配置签名与 Capability](#配置签名与-capability)
6. [构建与调试注意事项](#构建与调试注意事项)
7. [移植到其它项目](#移植到其它项目)
8. [常见问题](#常见问题)
9. [已知限制与后续 TODO](#已知限制与后续-todo)

---

## 功能概述

**CallKit** 让 iOS 收到 VoIP 推送时，能够像系统电话一样弹出来电界面；用户可以在锁屏、通知中心、应用内直接接听或挂断。当前项目把 CallKit 事件桥接到 Dart 版 `avenginekit`，由 Dart 处理实际的音视频通话。

依赖：PushKit、CallKit、avenginekit、imclient。

---

## 设计思路与核心文件

参考 `../ios-chat` 中的 `WFCCallKitManager`。原 iOS 项目直接使用原生 `WFAVEngineKit`；当前 Flutter 项目使用 Dart 版 `avenginekit`，因此需要把 CallKit 事件桥接到 Flutter：

- **原生负责**：PushKit 注册、VoIP Token 获取、系统来电 UI 报告、接听/挂断/静音事件。
- **Dart 负责**：把 VoIP Token 通过 `Imclient.setVoipDeviceToken` 上报服务器；在收到接听事件后驱动 `avenginekit` 实际接听。

### 核心文件

| 路径 | 说明 |
|---|---|
| `chat/ios/Runner/WFCCallKitManager.h` | CallKit/PushKit 管理类头文件 |
| `chat/ios/Runner/WFCCallKitManager.m` | 实现 `CXProviderDelegate`、`PKPushRegistryDelegate` |
| `chat/ios/Runner/AppDelegate.m` | 创建 `chat.wildfire/callkit` MethodChannel，注册 VoIP Push |
| `chat/lib/call/callkit_service.dart` | Dart 侧 CallKit 事件处理 |
| `chat/lib/main.dart` | 初始化 `CallKitService`，并同步通话状态 |

---

## 运行流程

1. 应用启动：`AppDelegate` 创建 `WFCCallKitManager`，注册 PushKit VoIP。
2. 系统下发 VoIP Token：`WFCCallKitManager` 通过 MethodChannel 调用 Dart `didUpdateVoipToken`。
3. Dart 调用 `Imclient.setVoipDeviceToken(token)` 上报服务器。
4. 收到来电 VoIP Push：原生立即 `reportNewIncomingCallWithUUID`，弹出系统来电界面。
5. 用户点击接听：原生发送 `performAnswerCall` 到 Dart。
6. Dart 检查 `avEngineKit.currentSession`：
   - 若已存在 incoming session，直接 `answerCall(false)`。
   - 若应用刚从 killed 状态唤醒，先记录 `pendingAnswerCallId`，等 `onReceiveCall` 触发后再自动接听。
7. 通话结束：Dart 通知原生 `reportCallEnded`，CallKit UI 关闭。

### MethodChannel 约定

原生 → Dart：

| 方法 | 参数 | 说明 |
|---|---|---|
| `didUpdateVoipToken` | `{token}` | 系统返回 VoIP Token |
| `didReceiveIncomingPush` | `{callId, callerId, callerName, audioOnly}` | 收到 VoIP Push |
| `performAnswerCall` | `{callId}` | 用户点击接听 |
| `performEndCall` | `{callId}` | 用户点击挂断 |
| `didChangeCallMute` | `{callId, muted}` | 用户切换静音 |

Dart → 原生：

| 方法 | 参数 | 说明 |
|---|---|---|
| `reportCallConnected` | `{callId}` | 通话接通 |
| `reportCallEnded` | `{callId}` | 通话结束 |

---

## 开启与关闭

参考 `../ios-chat` 的 `USE_CALL_KIT` 宏，当前项目在 **Runner target** 的编译期宏里添加了同名开关，**默认关闭**：

| 配置项 | 位置 | 默认值 |
|---|---|---|
| `USE_CALL_KIT` | `chat/ios/Runner.xcodeproj` → Runner target → Build Settings → Preprocessor Macros | `0` |

### 如何开启 CallKit

1. 打开 `chat/ios/Runner.xcodeproj/project.pbxproj`，把 Runner target 的 **Debug / Release / Profile** 三个配置里的：
   ```
   "USE_CALL_KIT=0",
   ```
   改为：
   ```
   "USE_CALL_KIT=1",
   ```
   共有 3 处，分别对应 Debug、Release、Profile。

2. 或在 Xcode 中操作：
   - 选中 `Runner` target → **Build Settings** → 搜索 **Preprocessor Macros**；
   - 在 Debug / Release / Profile 中把 `USE_CALL_KIT=0` 改为 `USE_CALL_KIT=1`。

3. 确保 `Runner/Info.plist` 的 `UIBackgroundModes` 包含 `voip`：
   ```xml
   <key>UIBackgroundModes</key>
   <array>
     <string>audio</string>
     <string>remote-notification</string>
     <string>voip</string>
   </array>
   ```

4. 在 Apple Developer 后台申请 **VoIP Push Certificate**，导出并上传到 IM 服务器；
   具体流程参考：[iOS 如何启用 CallKit](https://docs.wildfirechat.cn/blogs/iOS如何启用CallKit.html)。

5. 重新编译并安装到**真机**验证；模拟器无法接收 VoIP Push，无法完整测试来电弹窗。

### 如何关闭 CallKit

保持 `USE_CALL_KIT=0` 即可（当前默认）。此时：
- 应用启动时不会注册 PushKit VoIP Push；
- 不会弹出系统 CallKit 来电界面；
- 音视频来电走普通远程通知 + 应用内接听逻辑。

> 注意：`CallKit.framework` 和 `PushKit.framework` 仍保持链接，但不会被调用；如需彻底移除，需要同时取消 Link Binary With Libraries 中的框架并清理 `Info.plist` 的 `voip` 后台模式。

---

## 配置签名与 Capability

### VoIP Push Certificate

1. 登录 [Apple Developer Portal](https://developer.apple.com/account/)。
2. 在 Certificates, Identifiers & Profiles 中创建 **VoIP Services Certificate**。
3. 下载并导出 `.p12` 文件，上传到 IM 服务器。
4. 服务器配置完成后，才能向设备发送 VoIP Push，触发 CallKit 来电界面。

### App Group（与 Share Extension 共享）

如果项目同时启用 Share Extension，主应用需要开启 App Groups。CallKit 本身不强制要求 App Group，但当前项目里 CallKit 与 Share Extension 共用同一套原生代码，建议保持 App Group 配置一致。

---

## 构建与调试注意事项

1. **真机限制**：
   - 模拟器上可以编译，但 VoIP Push 和系统来电界面必须在真机上才能完整验证。
   - 需要在 Apple Developer 后台创建 VoIP Push Certificate，并上传到 IM 服务器。

2. **后台模式**：
   - `Info.plist` 中必须声明 `voip` 后台模式，否则系统会拒绝注册 PushKit VoIP。

3. **PushKit 注册时机**：
   - 必须在应用启动后尽快注册，通常在 `application:didFinishLaunchingWithOptions:` 中完成。

---

## 移植到其它项目

### 前置条件

- 目标项目为 Flutter iOS 项目，已配置 CocoaPods。
- 目标项目已接入 `imclient` 并支持 `setVoipDeviceToken`。
- 目标项目已接入 Dart 版音视频 SDK（如 `avenginekit`），且存在 `currentSession`、`answerCall()`、`hangup()`、`muteAudio()` 等 API。
- 拥有 Apple Developer 账号，可配置 VoIP Push Certificate。

### 1. 复制原生文件

把以下文件复制到目标项目的 `ios/Runner/` 目录：

```
chat/ios/Runner/WFCCallKitManager.h
chat/ios/Runner/WFCCallKitManager.m
```

### 2. 修改 `ios/Runner/AppDelegate.h/m`

在 `AppDelegate.m` 中：

- 引入头文件：

```objc
#import "WFCCallKitManager.h"
```

- 在 `application:didFinishLaunchingWithOptions:` 中，创建 MethodChannel 并初始化 CallKit：

```objc
BOOL result = [super application:application didFinishLaunchingWithOptions:launchOptions];
if (result) {
    FlutterViewController *controller = (FlutterViewController *)self.window.rootViewController;
    FlutterMethodChannel *callKitChannel = [FlutterMethodChannel
        methodChannelWithName:@"chat.wildfire/callkit"
              binaryMessenger:controller.binaryMessenger];
    self.callKitManager = [[WFCCallKitManager alloc] initWithMethodChannel:callKitChannel];
    [self.callKitManager registerVoipPush];
}
return result;
```

- 在 `AppDelegate` 的 class extension 中声明属性：

```objc
@property(nonatomic, strong) WFCCallKitManager *callKitManager;
```

- 用 `#if USE_CALL_KIT` 包裹上述 CallKit 相关代码（可选，推荐添加开关）。

### 3. Xcode 工程中添加文件

把 `WFCCallKitManager.h/m` 添加到 `Runner` target 的 Compile Sources 与 Headers。

### 4. 链接 CallKit / PushKit

在 `Runner` target 的 **Build Phases > Link Binary With Libraries** 中添加：

- `CallKit.framework`
- `PushKit.framework`

### 5. 添加编译期开关（推荐）

在 `Runner` target 的 **Build Settings > Preprocessor Macros** 中添加：

```
USE_CALL_KIT=0
```

并把 `AppDelegate.m` 中的 CallKit 导入和初始化代码用 `#if USE_CALL_KIT` 包裹，方便随时开启/关闭。

### 6. Dart 侧集成

复制 `chat/lib/call/callkit_service.dart` 到目标项目，并在 `main.dart` 中：

```dart
import 'call/callkit_service.dart';

// 在 avenginekit.init 后初始化
CallKitService.instance.init();
```

在 `AVEngineCallback.onReceiveCall` 和 `didCallEnded` 中分别调用：

```dart
CallKitService.instance.onReceiveCall(session);
CallKitService.instance.reportCallEnded(session.callId);
```

### 7. 配置 VoIP Push Certificate

参考前文[配置签名与 Capability](#配置签名与-capability)部分，创建并上传 VoIP Push Certificate。

---

## 常见问题

### Q1: 模拟器上 CallKit 不弹出来电界面？

模拟器无法注册 VoIP Push，也看不到系统来电 UI。必须在真机、且服务器已配置 VoIP Push 证书时测试。

### Q2: 开启 CallKit 后仍看不到来电界面？

- 确认 `USE_CALL_KIT=1` 已生效。
- 确认 `Info.plist` 的 `UIBackgroundModes` 包含 `voip`。
- 确认 Apple Developer 后台已创建 VoIP Push Certificate 并上传到服务器。
- 确认服务器下发的推送 payload 格式与本项目 `WFCCallKitManager.m` 中解析的格式一致（`wfc.sender`、`wfc.senderName`、`wfc.pushData`）。

### Q3: 通话已接听，但 CallKit UI 没有更新为“通话中”？

确认 Dart 侧在成功接听后调用了 `CallKitService.instance.reportCallConnected(session.callId)`。

### Q4: 如何关闭 CallKit？

把 `USE_CALL_KIT=1` 改回 `USE_CALL_KIT=0`，重新编译即可。

---

## 已知限制与后续 TODO

1. 当前未处理 CallKit 静音事件反向同步到 Dart（已预留 `didChangeCallMute`，可根据需要接入）。
2. 多设备同时收到来电时的去重逻辑依赖服务器侧 VoIP Push 策略。
3. 当前 Channel 通话未接入 CallKit，仅 Single/Group 通话通过 `avenginekit` 处理。
