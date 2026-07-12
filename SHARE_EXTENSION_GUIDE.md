# iOS Share Extension 功能说明与移植指南

本文档介绍当前 Flutter 项目里 iOS 端 Share Extension 分享功能的设计、文件分布、运行流程，以及如何把该功能移植到另一个 Flutter 项目。

---

## 目录

1. [功能概述](#功能概述)
2. [设计思路与核心文件](#设计思路与核心文件)
3. [运行流程](#运行流程)
4. [App Group 与权限配置](#app-group-与权限配置)
5. [构建与调试注意事项](#构建与调试注意事项)
6. [移植到其它项目](#移植到其它项目)
7. [常见问题](#常见问题)
8. [已知限制与后续 TODO](#已知限制与后续-todo)

---

## 功能概述

**Share Extension** 允许用户在其它应用（如 Safari、照片、文件）中点击“分享”时，选择“野火IM”，直接把内容发送到指定会话，无需先打开主应用。

支持的内容类型：

| 类型 | UTI | 处理方式 |
|---|---|---|
| 文本 | `public.plain-text` | 直接发送文本消息 |
| 链接 | `public.url` | 发送链接消息，尝试抓取 favicon 作为缩略图 |
| 图片 | `public.image` | 上传后发送图片消息 |
| 文件 | `public.file-url` | 上传后发送文件消息 |

依赖：App Groups、应用服务 REST API（`/messages/send`、`/media/upload/{mediaType}`）、imclient 会话数据。

---

## 设计思路与核心文件

参考 `../ios-chat` 的 Share Extension 实现：

- 主应用在后台时，把最近会话列表、应用服务认证信息写入 App Group。
- Share Extension 启动后读取这些信息，展示内容预览和操作入口。
- 用户选择“发给朋友”后进入会话列表，选择会话并确认发送。
- 用户选择“发给自己”后，直接发给文件传输助手 `wfc_file_transfer`。
- 发送过程中显示 `MBProgressHUD` 进度条，最后给出成功/失败提示。

### 核心文件

| 路径 | 说明 |
|---|---|
| `chat/ios/ShareExtension/ShareNavigationController.h/m` | 扩展入口导航控制器 |
| `chat/ios/ShareExtension/ShareViewController.h/m` | 扩展首页：解析分享内容、校验登录、显示预览、提供“发给朋友/发给自己”入口 |
| `chat/ios/ShareExtension/ConversationListViewController.h/m` | 会话列表页 |
| `chat/ios/ShareExtension/ConversationCell.h/m` | 会话 Cell |
| `chat/ios/ShareExtension/SharedConversation.h/m` | 共享会话模型 |
| `chat/ios/ShareExtension/ShareAppService.h/m` | 应用服务 API 客户端（文本/链接/图片/文件上传与发送） |
| `chat/ios/ShareExtension/ShareUtility.h/m` | 图片缩略图生成工具 |
| `chat/ios/ShareExtension/MBProgressHUD.h/m` | 进度/提示 HUD |
| `chat/ios/ShareExtension/Info.plist` | 扩展激活规则、`NSExtensionPrincipalClass` |
| `chat/ios/ShareExtension/ShareExtension.entitlements` | App Group 配置 |
| `chat/ios/Runner/AppDelegate.m` | 保存会话列表/认证信息到 App Group |
| `chat/lib/share/share_service.dart` | Dart 侧数据同步与分享内容接收 |
| `chat/lib/main.dart` | 后台同步触发 |

---

## 运行流程

### 主应用侧

1. 应用进入后台：`main.dart` 调用 `ShareService.instance.syncSharedDataOnBackground()`。
2. Dart 获取最近会话列表，分别查询单聊用户、群组、频道的名称和头像。
3. 读取 `SharedPreferences` 中的 `app_server_auth_token`。
4. 通过 MethodChannel 把数据传给 `AppDelegate.m`。
5. 原生写入 App Group NSUserDefaults：
   - `wfc_share_conversation_list`
   - `wfc_share_appservice_auth_token`
   - `wfc_share_appserver_address`

### 扩展侧

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

### 扩展 Info.plist

关键配置：

```xml
<key>NSExtension</key>
<dict>
  <key>NSExtensionAttributes</key>
  <dict>
    <key>NSExtensionActivationRule</key>
    <string>SUBQUERY (
      extensionItems, $extensionItem,
      SUBQUERY (
        $extensionItem.attachments, $attachment,
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.image" ||
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.plain-text" ||
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.url" ||
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.file-url"
      ).@count == 1
    ).@count &gt; 0</string>
  </dict>
  <key>NSExtensionPointIdentifier</key>
  <string>com.apple.share-services</string>
  <key>NSExtensionPrincipalClass</key>
  <string>ShareNavigationController</string>
</dict>
```

> 注意：`NSExtensionActivationRule` 必须放在 `NSExtensionAttributes` 下，而不是直接放在 `NSExtension` 下。

---

## 构建与调试注意事项

1. **Share Extension 签名**：
   - 扩展 Bundle ID 为 `cn.wildfirechat.messangerEx.ShareExtension`。
   - 必须开启 App Groups capability，且主应用与扩展使用同一个 App Group。
   - 第一次运行前需在 Xcode 中登录 Team 并选择对应 Provisioning Profile。

2. **应用服务地址**：
   - 扩展直接调用 `Config.APP_Server_Address` 对应的 REST API。
   - 确保服务器支持 `/messages/send` 和 `/media/upload/{mediaType}`。

3. **登录态同步**：
   - 扩展通过 App Group 中的 `authToken` 判断登录状态；如果主应用未进入过后台或 authToken 未写入，扩展会提示“请先登录”。

4. **Share Extension 在分享面板里不显示**：
   - 首先确认 `Runner.app/PlugIns/` 下包含 `ShareExtension.appex`；如果没有，检查 Xcode 中 **Runner → Build Phases → Embed App Extensions** 的设置为：
     - **Destination**: `PlugIns`
     - **Copy only when installing**: **取消勾选**（对应 `runOnlyForDeploymentPostprocessing = 0`）
     - 如果手工编辑 `project.pbxproj`，确保 `buildActionMask = 2147483647`。
   - 其次检查 `ShareExtension/Info.plist` 中的 `NSExtensionActivationRule` 是否放在 `NSExtensionAttributes` 下。
   - 安装新包后，分享面板可能需要几秒到几十秒刷新扩展列表；若仍不显示，可重启分享来源应用或设备。

---

## 移植到其它项目

### 前置条件

- 目标项目为 Flutter iOS 项目，已配置 CocoaPods。
- 目标项目已接入 `imclient`。
- 目标项目已有应用服务（App Server），支持 `/messages/send` 和 `/media/upload/{mediaType}`。
- 拥有 Apple Developer 账号，可配置 App Group。

### 1. 复制扩展文件

把 `chat/ios/ShareExtension/` 整个目录复制到目标项目的 `ios/` 目录下。

### 2. 修改扩展中的常量

打开 `ShareExtension` 下的文件，把 App Group ID、Bundle ID 前缀替换为目标项目：

- `ShareViewController.m`、`ConversationListViewController.m`、`ShareAppService.m` 中的：

```objc
static NSString * const kShareAppGroupId = @"group.your.bundle.id";
```

- `ShareExtension.entitlements` 中的 App Group。
- `ShareNavigationController.m` 中的根视图控制器可按需替换。

### 3. 修改 `ios/Runner/Runner.entitlements`

添加与扩展相同的 App Group：

```xml
<key>com.apple.security.application-groups</key>
<array>
  <string>group.your.bundle.id</string>
</array>
```

### 4. 修改 `ios/Runner/Info.plist`

添加 URL Scheme（可选，但建议保留，用于扩展唤起主应用）：

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>your.bundle.id.share</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>wfcchat</string>
    </array>
  </dict>
</array>
```

### 5. 修改 `ios/Runner/AppDelegate.m`

- 定义 App Group 相关 key：

```objc
static NSString * const kShareAppGroupId = @"group.your.bundle.id";
static NSString * const kShareItemsKey = @"wfc_share_items";
static NSString * const kSharedConversationsKey = @"wfc_share_conversation_list";
static NSString * const kSharedAuthTokenKey = @"wfc_share_appservice_auth_token";
static NSString * const kSharedAppServerAddressKey = @"wfc_share_appserver_address";
```

- 创建 `chat.wildfire/share` MethodChannel：

```objc
self.shareChannel = [FlutterMethodChannel
    methodChannelWithName:@"chat.wildfire/share"
          binaryMessenger:controller.binaryMessenger];
[self.shareChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
    if ([call.method isEqualToString:@"getPendingShareItems"]) {
        result(self.pendingShareItems ?: @[]);
        self.pendingShareItems = nil;
    } else if ([call.method isEqualToString:@"saveSharedConversations"]) {
        [self saveSharedConversations:call.arguments];
        result(@"OK");
    } else {
        result(FlutterMethodNotImplemented);
    }
}];
```

- 实现 `saveSharedConversations:` 写入 App Group。

### 6. Xcode 工程中添加 Share Extension target

推荐使用 Xcode 图形界面：

1. 打开 `Runner.xcworkspace`。
2. File > New > Target > Share Extension。
3. Product Name 填 `ShareExtension`，语言选 Objective-C。
4. 把步骤 1 复制的文件拖到该 target 中。
5. 在 target 的 **General > Deployment Info** 中设置 iOS 13.0+。
6. 在 **Signing & Capabilities** 中开启 App Groups，选择对应 Group。
7. 在 **Build Phases > Link Binary With Libraries** 添加 `MobileCoreServices.framework`、`QuartzCore.framework`、`CoreGraphics.framework`。
8. 在 `Runner` target 的 **Build Phases** 中确保存在 **Embed App Extensions**，并把 `ShareExtension.appex` 加入。

如果习惯命令行，也可参考本项目使用 `xcodeproj` gem 脚本化添加。

### 7. Dart 侧集成

复制 `chat/lib/share/share_service.dart` 到目标项目，并在 `main.dart` 中：

```dart
import 'share/share_service.dart';

ShareService.instance.init();
ShareService.instance.shareItemsStream.listen((items) {
  // 处理从扩展传入的分享项（如打开会话选择页）
});
```

在应用进入后台时调用：

```dart
ShareService.instance.syncSharedDataOnBackground();
```

该方法会读取 `SharedPreferences` 中的 `app_server_auth_token`，并把你项目里的应用服务地址传给原生。

**注意**：`syncSharedDataOnBackground` 里使用了 `Config.APP_Server_Address`，如果你的配置类不叫 `Config`，需要修改 `share_service.dart` 中的引用。

### 8. 配置签名与 Capability

1. 登录 [Apple Developer Portal](https://developer.apple.com/account/)。
2. 创建 App Group，格式为 `group.your.bundle.id`。
3. 为主应用 App ID 开启 App Groups。
4. 为 Share Extension App ID 开启 App Groups（Bundle ID 通常为主应用 ID + `.ShareExtension`）。
5. 重新生成 Provisioning Profiles。

---

## 常见问题

### Q1: Share Extension 提示“请先登录”？

主应用必须至少进入过一次后台，才能把 `app_server_auth_token` 写入 App Group。另外请检查主应用和扩展的 App Group 是否一致。

### Q2: Xcode 报 “Cycle inside Runner”？

这是 Share Extension 的 Embed App Extensions build phase 与 CocoaPods script phase 顺序冲突。把 **Embed App Extensions** 拖到 **Thin Binary** 之前即可。

### Q3: 扩展无法调用 `/messages/send`？

- 确认 `Config.APP_Server_Address` 正确。
- 确认服务器接口参数与本项目 `ShareAppService.m` 一致。
- 确认 `authToken` 已写入 App Group，且请求头字段为 `authToken`。

### Q4: 如何自定义 URL Scheme？

把 `wfcchat://share` 替换为你自己的 scheme，同时修改：

- `ios/Runner/Info.plist` 中的 `CFBundleURLSchemes`
- `ios/Runner/AppDelegate.m` 中的 `application:openURL:options:`

如果不再需要扩展唤起主应用，也可以完全移除 URL Scheme 相关代码。

### Q5: 如何修改“发给自己”的目标？

默认发给文件传输助手 `wfc_file_transfer`。如需修改，编辑 `ShareViewController.m` 中 `kFileTransferId` 常量。

---

## 已知限制与后续 TODO

1. 图片上传未做压缩选项；大图片会直接上传原图（`fullImage=YES` 时）。
2. 链接分享未抓取网页标题/缩略图，当前以 URL 本身作为标题。
3. 群组头像九宫格合成未实现；当前只使用 `portraitUrl`。
4. 多图分享只取第一张，未支持批量发送。
