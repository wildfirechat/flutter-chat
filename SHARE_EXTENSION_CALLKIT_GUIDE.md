# iOS CallKit / Share Extension 功能说明

本文档介绍当前 Flutter 项目里 iOS 端 CallKit 来电与 Share Extension 分享功能的设计、文件分布和运行流程。

---

## 目录

1. [功能概述](#功能概述)
2. [CallKit 集成](#callkit-集成)
3. [Share Extension 集成](#share-extension-集成)
4. [App Group 与权限配置](#app-group-与权限配置)
5. [构建与调试注意事项](#构建与调试注意事项)
6. [已知限制与后续 TODO](#已知限制与后续-todo)

---

## 功能概述

| 功能 | 作用 | 依赖 |
|---|---|---|
| **CallKit** | iOS 收到 VoIP 推送时，调起系统来电界面；用户接听/挂断/静音后，把事件交给 Flutter `avenginekit` 处理实际通话。 | PushKit、CallKit、avenginekit、imclient |
| **Share Extension** | 在其他应用里点击“分享”时，选择本应用，直接把内容发送到指定会话；无需先打开主应用。 | App Groups、应用服务 REST API、imclient 会话数据 |

两个功能都通过 **MethodChannel** 与 Flutter 通信，并依赖同一个 **App Group** 进行跨进程数据共享。

---

## CallKit 集成

### 设计思路

参考 `../ios-chat` 中的 `WFCCallKitManager`，但原 iOS 项目直接使用原生 `WFAVEngineKit`；当前 Flutter 项目使用 Dart 版 `avenginekit`，因此需要把 CallKit 事件桥接到 Flutter：

- 原生负责：PushKit 注册、VoIP Token 获取、系统来电 UI 报告、接听/挂断/静音事件。
- Dart 负责：把 VoIP Token 通过 `Imclient.setVoipDeviceToken` 上报服务器；在收到接听事件后驱动 `avenginekit` 实际接听。

### 核心文件

| 路径 | 说明 |
|---|---|
| `chat/ios/Runner/WFCCallKitManager.h` | CallKit/PushKit 管理类头文件 |
| `chat/ios/Runner/WFCCallKitManager.m` | 实现 `CXProviderDelegate`、`PKPushRegistryDelegate` |
| `chat/ios/Runner/AppDelegate.m` | 创建 `chat.wildfire/callkit` MethodChannel，注册 VoIP Push |
| `chat/lib/call/callkit_service.dart` | Dart 侧 CallKit 事件处理 |
| `chat/lib/main.dart` | 初始化 `CallKitService`，并同步通话状态 |

### 运行流程

1. 应用启动：`AppDelegate` 创建 `WFCCallKitManager`，注册 PushKit VoIP。
2. 系统下发 VoIP Token：`WFCCallKitManager` 通过 MethodChannel 调用 Dart `didUpdateVoipToken`。
3. Dart 调用 `Imclient.setVoipDeviceToken(token)` 上报服务器。
4. 收到来电 VoIP Push：原生立即 `reportNewIncomingCallWithUUID`，弹出系统来电界面。
5. 用户点击接听：原生发送 `performAnswerCall` 到 Dart。
6. Dart 检查 `avEngineKit.currentSession`：
   - 若已存在 incoming session，直接 `answerCall(false)`。
   - 若应用刚从 killed 状态唤醒，先记录 `pendingAnswerCallId`，等 `onReceiveCall` 触发后再自动接听。
7. 通话结束：Dart 通知原生 `reportCallEnded`，CallKit UI 关闭。

### 开启/关闭开关

参考 `../ios-chat` 的 `USE_CALL_KIT` 宏，当前项目在 **Runner target** 的编译期宏里添加了同名开关，**默认关闭**：

| 配置项 | 位置 | 默认值 |
|---|---|---|
| `USE_CALL_KIT` | `chat/ios/Runner.xcodeproj` → Runner target → Build Settings → Preprocessor Macros | `0` |

#### 如何开启 CallKit

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

#### 如何关闭 CallKit

保持 `USE_CALL_KIT=0` 即可（当前默认）。此时：
- 应用启动时不会注册 PushKit VoIP Push；
- 不会弹出系统 CallKit 来电界面；
- 音视频来电走普通远程通知 + 应用内接听逻辑。

> 注意：`CallKit.framework` 和 `PushKit.framework` 仍保持链接，但不会被调用；如需彻底移除，需要同时取消 Link Binary With Libraries 中的框架并清理 `Info.plist` 的 `voip` 后台模式。

---

## Share Extension 集成

### 设计思路

参考 `../ios-chat` 的 Share Extension：

- 主应用在后台时，把最近会话列表、应用服务认证信息写入 App Group。
- Share Extension 启动后读取这些信息，展示会话列表。
- 用户选择会话后，Extension 直接调用应用服务 REST API 发送消息。

### 核心文件

| 路径 | 说明 |
|---|---|
| `chat/ios/ShareExtension/ShareViewController.h/m` | 扩展入口：解析分享内容、校验登录、弹出会话列表 |
| `chat/ios/ShareExtension/ConversationListViewController.h/m` | 会话列表页 |
| `chat/ios/ShareExtension/ConversationCell.h/m` | 会话 Cell |
| `chat/ios/ShareExtension/SharedConversation.h/m` | 共享会话模型 |
| `chat/ios/ShareExtension/ShareAppService.h/m` | 应用服务 API 客户端（文本/链接/图片/文件） |
| `chat/ios/ShareExtension/Info.plist` | 扩展激活规则 |
| `chat/ios/ShareExtension/ShareExtension.entitlements` | App Group 配置 |
| `chat/ios/Runner/AppDelegate.m` | 保存会话列表/认证信息到 App Group |
| `chat/lib/share/share_service.dart` | Dart 侧数据同步与分享内容接收 |
| `chat/lib/main.dart` | 后台同步触发 |

### 运行流程

#### 主应用侧

1. 应用进入后台：`main.dart` 调用 `ShareService.instance.syncSharedDataOnBackground()`。
2. Dart 获取最近会话列表，分别查询单聊用户、群组、频道的名称和头像。
3. 读取 `SharedPreferences` 中的 `app_server_auth_token`。
4. 通过 MethodChannel 把数据传给 `AppDelegate.m`。
5. 原生写入 App Group NSUserDefaults：
   - `wfc_share_conversation_list`
   - `wfc_share_appservice_auth_token`
   - `wfc_share_appserver_address`

#### 扩展侧

1. 用户在其它应用选择“分享到 野火IM”。
2. 系统根据 `Info.plist` 的 `NSExtensionPrincipalClass` 实例化 `ShareNavigationController`，根视图为 `ShareViewController`。
3. `ShareViewController` 顶部显示内容预览，下方列表提供两个入口：
   - **发给朋友**：push 进入 `ConversationListViewController` 选择会话。
   - **发给自己**：直接发给文件传输助手（`wfc_file_transfer`）。
4. 选择会话（或“发给自己”）后，先弹 Alert **确认发送给 xxx**。
5. 确认后显示 `MBProgressHUD` 进度：
   - 文本/链接：直接发送。
   - 图片/文件：先上传，实时更新进度条，再发送消息。
6. 成功：弹“已发送 / 请在野火IM中查看”；失败：弹“网络错误”。

---

## App Group 与权限配置

### App Group ID

统一使用：

```
group.cn.wildfirechat.messangerEx
```

- 主应用：`Runner/Runner.entitlements`
- 扩展：`ShareExtension/ShareExtension.entitlements`

### 主应用 Info.plist

已添加 URL Scheme `wfcchat`，用于扩展唤起主应用（备用入口）：

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>cn.wildfirechat.messangerEx.share</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>wfcchat</string>
    </array>
  </dict>
</array>
```

### 后台模式

`Info.plist` 中已声明：

```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
  <string>remote-notification</string>
  <string>voip</string>
</array>
```

---

## 构建与调试注意事项

1. **CallKit 真机限制**：
   - 模拟器上可以编译，但 VoIP Push 和系统来电界面必须在真机上才能完整验证。
   - 需要在 Apple Developer 后台创建 VoIP Push Certificate，并上传到 IM 服务器。

2. **Share Extension 签名**：
   - 扩展 Bundle ID 为 `cn.wildfirechat.messangerEx.ShareExtension`。
   - 必须开启 App Groups capability，且主应用与扩展使用同一个 App Group。
   - 第一次运行前需在 Xcode 中登录 Team 并选择对应 Provisioning Profile。

3. **应用服务地址**：
   - 扩展直接调用 `Config.APP_Server_Address` 对应的 REST API。
   - 确保服务器支持 `/messages/send` 和 `/media/upload/{mediaType}`。

4. **登录态同步**：
   - 扩展通过 App Group 中的 `authToken` 判断登录状态；如果主应用未进入过后台或 authToken 未写入，扩展会提示“请先登录”。

5. **Share Extension 在分享面板里不显示**：
   - 首先确认 `Runner.app/PlugIns/` 下包含 `ShareExtension.appex`；如果没有，检查 Xcode 中 **Runner → Build Phases → Embed App Extensions** 的设置为：
     - **Destination**: `PlugIns`
     - **Copy only when installing**: **取消勾选**（对应 `runOnlyForDeploymentPostprocessing = 0`）
     - 如果手工编辑 `project.pbxproj`，确保 `buildActionMask = 2147483647`。
   - 其次检查 `ShareExtension/Info.plist` 中的 `NSExtensionActivationRule` 必须放在 `NSExtensionAttributes` 下，而不是直接放在 `NSExtension` 下：
     ```xml
     <key>NSExtension</key>
     <dict>
       <key>NSExtensionAttributes</key>
       <dict>
         <key>NSExtensionActivationRule</key>
         <string>...</string>
       </dict>
       ...
     </dict>
     ```
   - 安装新包后，分享面板可能需要几秒到几十秒刷新扩展列表；若仍不显示，可重启分享来源应用或设备。

---

## 已知限制与后续 TODO

1. **CallKit**：
   - 当前未处理 CallKit 静音事件反向同步到 Dart（已预留 `didChangeCallMute`，可根据需要接入）。
   - 多设备同时收到来电时的去重逻辑依赖服务器侧 VoIP Push 策略。

2. **Share Extension**：
   - 图片上传未做压缩；大图片会直接上传原图。
   - 链接分享未抓取网页标题/缩略图，当前以 URL 本身作为标题。
   - 群组头像九宫格合成未实现；当前只使用 `portraitUrl`。
   - 分享到“文件传输助手”的快捷入口未添加。

3. **通用**：
   - 当前 Channel 通话未接入 CallKit，仅 Single/Group 通话通过 `avenginekit` 处理。
