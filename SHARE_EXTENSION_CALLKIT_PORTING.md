# CallKit / Share Extension 移植指南

本文档说明如何把本项目的 iOS CallKit 来电与 Share Extension 分享功能移植到另一个 Flutter 项目。以下假设目标项目已集成 `imclient` 与 `avenginekit`（或等价的音视频通话 SDK）。

---

## 目录

1. [前置条件](#前置条件)
2. [移植 CallKit](#移植-callkit)
3. [移植 Share Extension](#移植-share-extension)
4. [配置签名与 Capability](#配置签名与-capability)
5. [常见问题](#常见问题)

---

## 前置条件

- 目标项目为 Flutter iOS 项目，已配置 CocoaPods。
- 目标项目已接入 `imclient` 并支持 `setVoipDeviceToken`。
- 目标项目已接入 Dart 版音视频 SDK（如 `avenginekit`），且存在 `currentSession`、`answerCall()`、`hangup()`、`muteAudio()` 等 API。
- 目标项目已有应用服务（App Server），支持 `/messages/send` 和 `/media/upload/{mediaType}`。
- 拥有 Apple Developer 账号，可配置 App Group、VoIP Push Certificate。

---

## 移植 CallKit

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

### 3. Xcode 工程中添加文件

把 `WFCCallKitManager.h/m` 添加到 `Runner` target 的 Compile Sources 与 Headers。

### 4. 链接 CallKit / PushKit

在 `Runner` target 的 **Build Phases > Link Binary With Libraries** 中添加：

- `CallKit.framework`
- `PushKit.framework`

### 5. Dart 侧集成

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

### 6. MethodChannel 约定

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

## 移植 Share Extension

### 1. 复制扩展文件

把 `chat/ios/ShareExtension/` 整个目录复制到目标项目的 `ios/` 目录下。

### 2. 修改扩展中的常量

打开 `ShareExtension` 下的文件，把 App Group ID、Bundle ID 前缀替换为目标项目：

- `ShareViewController.m`、`ConversationListViewController.m`、`ShareAppService.m` 中的：

```objc
static NSString * const kShareAppGroupId = @"group.your.bundle.id";
```

- `ShareExtension.entitlements` 中的 App Group。

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
7. 在 **Build Phases > Link Binary With Libraries** 添加 `MobileCoreServices.framework`。
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

---

## 配置签名与 Capability

### App Group

1. 登录 [Apple Developer Portal](https://developer.apple.com/account/)。
2. 创建 App Group，格式为 `group.your.bundle.id`。
3. 为主应用 App ID 开启 App Groups。
4. 为 Share Extension App ID 开启 App Groups（Bundle ID 通常为主应用 ID + `.ShareExtension`）。
5. 重新生成 Provisioning Profiles。

### VoIP Push Certificate

1. 在 Apple Developer Portal 创建 VoIP Services Certificate。
2. 导出 `.p12` 并上传到 IM 服务器。
3. 服务器才能向设备发送 VoIP Push，触发 CallKit 来电界面。

---

## 常见问题

### Q1: 模拟器上 CallKit 不弹出来电界面？

模拟器无法注册 VoIP Push，也看不到系统来电 UI。必须在真机、且服务器已配置 VoIP Push 证书时测试。

### Q2: Share Extension 提示“请先登录”？

主应用必须至少进入过一次后台，才能把 `app_server_auth_token` 写入 App Group。另外请检查主应用和扩展的 App Group 是否一致。

### Q3: Xcode 报 “Cycle inside Runner”？

这是 Share Extension 的 Embed App Extensions build phase 与 CocoaPods script phase 顺序冲突。把 **Embed App Extensions** 拖到 **Thin Binary** 之前即可。

### Q4: 扩展无法调用 `/messages/send`？

- 确认 `Config.APP_Server_Address` 正确。
- 确认服务器接口参数与本项目 `ShareAppService.m` 一致。
- 确认 `authToken` 已写入 App Group，且请求头字段为 `authToken`。

### Q5: 如何自定义 URL Scheme？

把 `wfcchat://share` 替换为你自己的 scheme，同时修改：

- `ios/Runner/Info.plist` 中的 `CFBundleURLSchemes`
- `ios/ShareExtension/ShareViewController.m` 中的 `openHostApp`
- `ios/Runner/AppDelegate.m` 中的 `application:openURL:options:`

如果不再需要扩展唤起主应用，也可以完全移除 URL Scheme 相关代码。
